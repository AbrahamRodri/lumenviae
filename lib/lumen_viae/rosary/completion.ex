defmodule LumenViae.Rosary.Completion do
  @moduledoc """
  A record that someone finished praying a meditation set, with the
  approximate place and the surface it was prayed from. Analytics only.

  ## What is deliberately not here

  No account, device or install identifier, and nothing that survives from
  one completion to the next. Two Rosaries prayed from the same phone are
  indistinguishable from two prayed by strangers, which is the point: the
  table answers "how many, from where, on what" and cannot be made to
  answer "who".

  `ip_prefix` is a truncated network prefix, never a full address - see
  `LumenViae.Services.Geolocation.anonymize/1`. It is coarse enough that it cannot
  single out a household and specific enough to tell two cities apart.

  `prayed_aloud` says whether the spoken Rosary was on. It is `nil` when
  the client did not say, which is every row from before it existed.

  `time_zone` and `locale` are reported by the client. On iOS both are
  readable without any permission prompt, so nothing here is gated behind a
  dialog the reader has to be talked through.

  ## Almost nothing here is public

  A completion can be read back as its id, its set and the moment it was
  recorded, which is the whole of what the REST API answers a write with.
  Every other attribute is private, so no API built on the resource can
  read where a completion came from: the rows are written by the public and
  read only by the admin analytics.

  ## Two ways in

  `:record` is the server-side write, used by the website and the REST
  controller, which say what surface they are. `:record_from_app` is the
  public write: the client names the set and whether it prayed aloud, and
  nothing else. Neither takes the address or the moment as an input; see
  `LumenViae.Rosary.Completion.Stamp`.

  Mapped onto the existing `rosary_completions` table exactly as the Ecto
  migrations left it, which is why there is no `updated_at`.

  Reach completions through `LumenViae.Rosary`; nothing outside
  `lib/lumen_viae/rosary/` names this module.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Rosary,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshRateLimiter, AshOban]

  alias LumenViae.Rosary.Completion.LookUpPlace
  alias LumenViae.Rosary.Completion.RateLimit
  alias LumenViae.Rosary.Completion.SetIsVisible
  alias LumenViae.Rosary.Completion.Stamp

  @sources ~w(web ios)

  @doc """
  The surfaces a completion can be reported from.
  """
  def sources, do: @sources

  # GraphQL's recordCompletion answers with id, meditationSetId and
  # completedAt, exactly the REST response; nothing else is public. The
  # set's id is a GraphQL ID, as it is on the set itself.
  graphql do
    type :completion
    relationships []
    attribute_types meditation_set_id: :id
    argument_input_types record_from_app: [meditation_set_id: non_null(:id)]
    derive_filter? false
    derive_sort? false
  end

  postgres do
    table "rosary_completions"
    repo LumenViae.Repo

    migration_types ip_prefix: :string,
                    city: :string,
                    region: :string,
                    country: :string,
                    country_code: :string,
                    source: :string,
                    time_zone: :string,
                    locale: :string

    migration_defaults inserted_at: "nil"

    references do
      reference :meditation_set, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:completed_at]
      index [:country_code]
      index [:source]
    end
  end

  # Where the counters live. The limit itself is `RateLimit`, on both
  # actions that record a completion, rather than a `rate_limit` entry here:
  # see its moduledoc.
  rate_limit do
    backend LumenViae.Limits.Backend
  end

  # The place lookup, as a background job. `Stamp` enqueues one for each
  # completion that can be placed, once the row has committed; nothing
  # polls for unplaced rows, so there is no scheduler. The job's arguments
  # are the completion's id and nothing else: the lookup reads the stored
  # prefix, so the full address is never written into a job. A completion
  # that already has a place no longer matches `where`, and its job is
  # cancelled rather than run twice. See docs/ARCHITECTURE.md, "Background
  # jobs".
  oban do
    triggers do
      trigger :locate do
        action :add_place
        queue :geolocation
        where expr(not is_nil(ip_prefix) and is_nil(country_code))
        scheduler_cron false
        max_attempts 3
        # The lookup is an HTTP call, made before the update's own
        # transaction opens; locking the row first would hold a connection
        # open across it.
        lock_for_update? false
        worker_module_name LumenViae.Rosary.Completion.LocateWorker
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    read :in_range do
      description "The completions between two moments, oldest first."

      argument :since, :utc_datetime do
        allow_nil? false
      end

      argument :until, :utc_datetime do
        allow_nil? false
      end

      filter expr(completed_at >= ^arg(:since) and completed_at <= ^arg(:until))
      prepare build(sort: [completed_at: :asc, id: :asc])
    end

    read :recent do
      description "The most recent completions, newest first."

      argument :limit, :integer do
        allow_nil? false
        constraints min: 1
      end

      prepare build(sort: [completed_at: :desc, id: :desc])
      prepare fn query, _context -> Ash.Query.limit(query, query.arguments.limit) end
    end

    create :record do
      description "Records that somebody finished praying a set, from the website or the REST API. The surface, the timezone and the locale are whatever the server-side caller reports; the moment and the address are taken by the action itself."
      primary? true

      argument :meditation_set_id, :integer do
        allow_nil? false
      end

      argument :source, :string
      argument :time_zone, :string
      argument :locale, :string
      argument :prayed_aloud, :boolean

      change set_attribute(:meditation_set_id, arg(:meditation_set_id))
      change set_attribute(:source, arg(:source))
      change set_attribute(:time_zone, arg(:time_zone))
      change set_attribute(:locale, arg(:locale))
      change set_attribute(:prayed_aloud, arg(:prayed_aloud))
      change RateLimit
      change Stamp
    end

    create :record_from_app do
      description "Records a finished Rosary reported by the app over the public write API. The client says which set and whether it was prayed aloud, and nothing else: the surface is always the app, and the set must be one the public can see."

      argument :meditation_set_id, :integer do
        allow_nil? false
      end

      argument :prayed_aloud, :boolean

      change set_attribute(:meditation_set_id, arg(:meditation_set_id))
      change set_attribute(:prayed_aloud, arg(:prayed_aloud))
      change set_attribute(:source, "ios")
      change RateLimit

      # After the limit, in a `before_action`, so that a refused request has
      # not already cost a query to find out whether its set exists, and a
      # request for a set that does not exist spends the budget like any
      # other.
      validate SetIsVisible, before_action?: true
      change Stamp
    end

    update :place do
      description "Attaches a looked-up place to a completion that has already been written."
      accept [:city, :region, :country, :country_code]
    end

    update :add_place do
      description "Looks up a rough place for a completion from its stored network prefix and attaches it. Run by the :locate trigger in the background, never on the request path."
      require_atomic? false
      change LookUpPlace
    end
  end

  # Anybody may record that they finished a Rosary - the website and REST
  # through :record, GraphQL through :record_from_app - behind the crawler
  # check the web layer puts in front of both, and the rate limit both
  # carry. Reading the rows back is the admin analytics' alone; so is
  # everything else.
  policies do
    bypass LumenViae.Accounts.Checks.ActorIsAdmin do
      authorize_if always()
    end

    policy action([:record, :record_from_app]) do
      authorize_if always()
    end

    # The place lookup job (the :locate trigger) reads the row and writes
    # the place with no actor, after the response has gone. It is let
    # through by AshOban's own check, which matches only the private context
    # AshOban's worker sets: nothing a client sends can set it, so the
    # public cannot reach :add_place, and the job needs no authorize?: false.
    policy [action([:read, :add_place]), AshOban.Checks.AshObanInteraction] do
      authorize_if always()
    end
  end

  validations do
    validate one_of(:source, @sources), where: [changing(:source)], message: "is invalid"
  end

  attributes do
    integer_primary_key :id

    attribute :completed_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :ip_prefix, :string do
      constraints max_length: 255, trim?: false
    end

    attribute :city, :string do
      constraints max_length: 255, trim?: false
    end

    attribute :region, :string do
      constraints max_length: 255, trim?: false
    end

    attribute :country, :string do
      constraints max_length: 255, trim?: false
    end

    attribute :country_code, :string do
      constraints max_length: 255, trim?: false
    end

    # "web" or "ios": which surface the Rosary was prayed on, so the two can
    # be read apart instead of summing into one uninterpretable number.
    attribute :source, :string do
      constraints max_length: 255, trim?: false
    end

    # Client-reported strings arrive from a request body and are stored
    # unread by anything that would sanitise them, so they are bounded here
    # rather than trusted to be the short identifiers they are meant to be.
    attribute :time_zone, :string do
      constraints max_length: 64, trim?: false
    end

    attribute :locale, :string do
      constraints max_length: 32, trim?: false
    end

    attribute :prayed_aloud, :boolean

    create_timestamp :inserted_at, type: :naive_datetime
  end

  relationships do
    belongs_to :meditation_set, LumenViae.Rosary.MeditationSet do
      attribute_type :integer
      allow_nil? false
      attribute_public? true
    end
  end

  calculations do
    # The double `AT TIME ZONE` is not redundant. `completed_at` is
    # `timestamp without time zone`, and for a naive timestamp Postgres
    # reads `AT TIME ZONE zone` as "this value is already in `zone`" and
    # converts *out* of it - the opposite of what is wanted here, and wrong
    # by the offset rather than merely imprecise. A single conversion
    # therefore filed every Rosary prayed between seven in the evening and
    # midnight Central under the following day, which is a good part of the
    # praying that happens at all.
    #
    # So the value is first stamped as UTC, which is what it is, and only
    # then converted to the reporting zone.
    calculate :local_day,
              :date,
              expr(
                fragment(
                  "date_trunc('day', (? AT TIME ZONE 'UTC') AT TIME ZONE ?)::date",
                  completed_at,
                  ^arg(:time_zone)
                )
              ) do
      description "The calendar day the Rosary was finished on, in the given zone rather than in UTC: a Rosary prayed at nine in the evening in Texas belongs to that evening, not to the next morning. Postgres carries the zone database, so the shift is done there."

      argument :time_zone, :string do
        allow_nil? false
      end
    end
  end
end
