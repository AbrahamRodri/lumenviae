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

  ## Nothing here is public

  Every attribute but the id is private, so no API built on the resource
  can read a completion back out: the rows are written by the public and
  read only by the admin analytics.

  Mapped onto the existing `rosary_completions` table exactly as the Ecto
  migrations left it, which is why there is no `updated_at`.

  Reach completions through `LumenViae.Rosary`; nothing outside
  `lib/lumen_viae/rosary/` names this module.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Rosary,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource]

  graphql do
    type :completion
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

  actions do
    defaults [
      :read,
      :destroy,
      create: [
        :meditation_set_id,
        :completed_at,
        :ip_prefix,
        :city,
        :region,
        :country,
        :country_code,
        :source,
        :time_zone,
        :locale,
        :prayed_aloud
      ]
    ]
  end

  attributes do
    integer_primary_key :id

    attribute :completed_at, :utc_datetime do
      allow_nil? false
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
      attribute_writable? true
    end
  end
end
