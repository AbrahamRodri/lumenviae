defmodule LumenViae.Rosary.MeditationSet do
  @moduledoc """
  A curated collection of meditations prayed together as one Rosary.

  ## Visibility

  A set is hidden from the public site and from both APIs when any of its
  meditations is archived, or when it has no meditations at all. Archiving
  a single meditation therefore hides every set that contains it, and a set
  is not public between being created and being given its first
  meditation: there is nothing in it to pray, and listing it would only
  offer a page that cannot open. The admin keeps seeing everything. That
  rule is the `visible?` calculation, and the `:visible` read is the only
  door the public surfaces come through, so a hidden set cannot be listed
  and cannot be fetched by id either.

  ## Order

  Sets are listed by category and then in creation order. The order is part
  of the iOS API contract - the app builds its filter chips and sections
  from first appearance across the list response - so every read here
  declares it.

  A set's meditations are prayed in the order carried by the join row, not
  by the meditations themselves, which is why `set_memberships` is sorted
  and is the path to follow for prayer order.

  ## Byline

  `author` and `source` are the set's own byline. When they are blank the
  byline is derived from the set's meditations (`derived_author`,
  `derived_source`), and only when every one of them agrees.
  `byline_author` and `byline_source` are what a client is shown: the
  explicit value, or else the derivation.

  ## Artwork

  The artwork columns, and the two actions that write them, come from
  `LumenViae.Rosary.Artwork.Fragment`. A set with no publishable painting
  of its own shows its linked author's portrait instead; see
  `LumenViae.Rosary.artwork_record/1`.

  Mapped onto the existing `meditation_sets` table exactly as the Ecto
  migrations left it.

  Reach sets through `LumenViae.Rosary`; nothing outside
  `lib/lumen_viae/rosary/` names this module.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Rosary,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource, AshPaperTrail.Resource],
    fragments: [LumenViae.Rosary.Artwork.Fragment]

  alias LumenViae.Rosary.Categories
  alias LumenViae.Rosary.MeditationSet.Byline
  alias LumenViae.Rosary.MeditationSet.DerivedAttribution
  alias LumenViae.Rosary.MeditationSet.ManagedLabels
  alias LumenViae.Rosary.MeditationSet.NormalizeLabels

  # GraphQL shows a set's text, its byline and artwork as the clients
  # print them, and its meditations in prayer order through
  # set_memberships. The raw byline columns, the id-ordered meditations,
  # the author link and the completions stay out. See docs/GRAPHQL.md.
  graphql do
    type :meditation_set
    relationships [:set_memberships]
    # A prayer is the whole set: no limit or offset on its meditations.
    paginate_relationship_with set_memberships: :none
    hide_fields [:author, :source, :author_id]
    field_names byline_author: :author, byline_source: :source
    derive_filter? false
    derive_sort? false
  end

  # The JSON:API at /api/v2 shows what GraphQL shows, under the same names:
  # the byline and artwork as the clients print them, and the meditations
  # in prayer order through set_memberships, included on request
  # (?include=set_memberships.meditation.mystery). No filter or sort beyond
  # the action's own. See docs/JSON_API.md.
  json_api do
    type "meditation_set"

    show_fields [
      :name,
      :category,
      :description,
      :labels,
      :byline_author,
      :byline_source,
      :artwork,
      :set_memberships
    ]

    default_fields [
      :name,
      :category,
      :description,
      :labels,
      :byline_author,
      :byline_source,
      :artwork
    ]

    field_names byline_author: :author, byline_source: :source
    includes set_memberships: [meditation: [:mystery]]
    derive_filter? false
    derive_sort? false
  end

  postgres do
    table "meditation_sets"
    repo LumenViae.Repo

    migration_types name: :string,
                    category: :string,
                    labels: {:array, :string},
                    author: :string,
                    image_key: :string,
                    image_width: :integer,
                    image_height: :integer,
                    image_title: :string,
                    image_artist: :string,
                    image_year: :string,
                    image_source_url: :string,
                    image_license: :string

    migration_defaults inserted_at: "nil", updated_at: "nil"

    references do
      # Deleting an author must not delete or hide their sets; the sets just
      # lose the linked record and fall back to their own artwork and byline.
      reference :author_profile, on_delete: :nilify, index?: true
    end

    check_constraints do
      check_constraint :image_focal_x, "image_focal_x_in_range",
        check: "image_focal_x >= 0.0 AND image_focal_x <= 1.0",
        message: "must be between 0.0 and 1.0"

      check_constraint :image_focal_y, "image_focal_y_in_range",
        check: "image_focal_y >= 0.0 AND image_focal_y <= 1.0",
        message: "must be between 0.0 and 1.0"
    end

    custom_indexes do
      index [:category]
    end
  end

  # Every create, update and destroy leaves a version row holding the whole
  # record as it stood afterwards (or, for a destroy, as it stood last), so
  # an edit can always be seen and reversed. The action that made it is
  # stored with it. The two timestamps are left out because they change
  # with every write and say nothing a version's own timestamp does not;
  # the primary key is left out by the extension.
  #
  # No foreign key from a version to its record: the record can really be
  # deleted, and its versions are the one place its last state survives.
  paper_trail do
    change_tracking_mode :snapshot
    store_action_name? true
    ignore_attributes [:inserted_at, :updated_at]

    # Display variants are a derived copy of a painting already recorded,
    # not an edit, so making them leaves the History panel alone.
    ignore_actions [:record_artwork_variants]
    reference_source? false

    # Which admin made the change: the actor of the action, when it is one.
    # Nil for an operator's shell (mix tasks, LumenViae.Release), which runs
    # with no actor, and for rows written before this was recorded. Removing
    # an admin keeps their history and forgets only who made it.
    belongs_to_actor :admin, LumenViae.Accounts.Admin,
      domain: LumenViae.Accounts,
      on_delete: :nilify

    # Admin-only, read-only history. See LumenViae.Rosary.VersionPolicies.
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin LumenViae.Rosary.VersionPolicies
  end

  actions do
    # Deleting a set takes its memberships and its completions with it: both
    # foreign keys cascade. The meditations themselves stay.
    defaults [:read, :destroy]

    read :catalogue do
      description "Every set, hidden ones included, by category and then in creation order. The admin's list."
      prepare build(sort: [category: :asc, id: :asc])
    end

    read :visible do
      description "The sets the public may see: those with at least one meditation and none archived. By category and then in creation order, optionally narrowed to one category. Never paginated."

      argument :category, :string

      filter expr(visible? and (is_nil(^arg(:category)) or category == ^arg(:category)))
      prepare build(sort: [category: :asc, id: :asc])
    end

    read :named do
      description "The sets carrying this exact name, optionally within one category. Names repeat across categories."

      argument :name, :string do
        allow_nil? false
        constraints trim?: false, allow_empty?: true
      end

      argument :category, :string

      filter expr(
               name == ^arg(:name) and (is_nil(^arg(:category)) or category == ^arg(:category))
             )

      prepare build(sort: [id: :asc])
    end

    read :missing_artwork do
      description "The sets with no painting uploaded."
      filter expr(is_nil(image_key))
      prepare build(sort: [id: :asc])
    end

    # The artwork columns are in neither accept list. They are written by
    # the fragment's two actions, for the same reason archived_at is not
    # writable on a meditation.
    create :create do
      primary? true
      accept [:name, :category, :description, :labels, :author, :source, :author_id]
      change NormalizeLabels
      validate ManagedLabels
    end

    update :update do
      primary? true
      accept [:name, :category, :description, :labels, :author, :source, :author_id]

      # The label rules read the list being written, in Elixir.
      require_atomic? false
      change NormalizeLabels
      validate ManagedLabels
    end
  end

  # The public may read the sets it may see, by any read: `visible?` is the
  # same rule the :visible read filters on, so a hidden set is invisible to
  # an anonymous caller whichever read it tries, and not-found by id.
  # Everything else is the console's.
  policies do
    bypass LumenViae.Accounts.Checks.ActorIsAdmin do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(visible?)
    end
  end

  validations do
    validate one_of(:category, Categories.slugs()),
      where: [changing(:category)],
      message: "is invalid"
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255, trim?: false
    end

    # One of `LumenViae.Rosary.Categories.slugs/0`. A plain string, because
    # the APIs serialise it as one and the iOS app matches it exactly.
    attribute :category, :string do
      allow_nil? false
      public? true
      constraints max_length: 255, trim?: false
    end

    attribute :description, :string do
      public? true
      constraints trim?: false
    end

    # Matched by the iOS app as exact case-sensitive strings, and the first
    # label is the set's primary group, so the curated order is kept.
    attribute :labels, {:array, :string} do
      allow_nil? false
      default []
      public? true
      constraints items: [max_length: 255, trim?: false]
    end

    # The set's own byline. When these are blank the byline is derived from
    # the set's meditations - never written back into these, or a later save
    # would persist the derivation as an explicit override and it would go
    # stale the moment a meditation's attribution was fixed.
    attribute :author, :string do
      public? true
      constraints max_length: 255, trim?: false
    end

    attribute :source, :string do
      public? true
      constraints trim?: false
    end

    create_timestamp :inserted_at, type: :naive_datetime
    update_timestamp :updated_at, type: :naive_datetime
  end

  relationships do
    # The linked author record, distinct from the `author` byline string
    # above: the byline is display text, the link is what lets the set
    # inherit the author's portrait when it has no artwork of its own.
    belongs_to :author_profile, LumenViae.Rosary.Author do
      source_attribute :author_id
      attribute_type :integer
      attribute_writable? true
      attribute_public? true
      public? true
    end

    # In the order the set is prayed. To read a set's meditations in prayer
    # order, follow these to their meditation.
    has_many :set_memberships, LumenViae.Rosary.SetMembership do
      sort order: :asc
      public? true
    end

    # Oldest meditation first, which is not prayer order: a many-to-many
    # cannot be sorted by its join row. Use `set_memberships` for that.
    many_to_many :meditations, LumenViae.Rosary.Meditation do
      through LumenViae.Rosary.SetMembership
      join_relationship :set_memberships
      source_attribute_on_join_resource :meditation_set_id
      destination_attribute_on_join_resource :meditation_id
      sort id: :asc
      public? true
    end

    has_many :completions, LumenViae.Rosary.Completion
  end

  calculations do
    # Built on the two unauthorized aggregates below rather than on
    # `exists(meditations, ...)`, which would be authorized against
    # Meditation's policies: an anonymous caller cannot see archived
    # meditations, so for it "holds an archived meditation" would always be
    # false and every hidden set would turn visible.
    calculate :visible?,
              :boolean,
              expr(holds_meditations? and not holds_archived_meditation?) do
      description "Whether the public may see the set: it has at least one meditation, and none of them is archived."
    end

    calculate :derived_author, :string, {DerivedAttribution, field: :author} do
      description "The author every meditation in the set agrees on, or nil."
    end

    calculate :derived_source, :string, {DerivedAttribution, field: :source} do
      description "The source every meditation in the set agrees on, or nil."
    end

    calculate :byline_author, :string, {Byline, field: :author} do
      description "The author the set is shown with: its own, or else the one its meditations agree on."
      public? true
    end

    calculate :completion_count,
              :integer,
              expr(
                count(completions,
                  query: [
                    filter:
                      expr(
                        (is_nil(^arg(:since)) or completed_at >= ^arg(:since)) and
                          (is_nil(^arg(:until)) or completed_at <= ^arg(:until))
                      )
                  ]
                )
              ) do
      description "How many times the set has been prayed to the end, optionally between two moments."
      argument :since, :utc_datetime
      argument :until, :utc_datetime
    end

    calculate :byline_source, :string, {Byline, field: :source} do
      description "The source the set is shown with: its own, or else the one its meditations agree on."
      public? true
    end

    calculate :artwork,
              LumenViae.Rosary.Types.Artwork,
              LumenViae.Rosary.MeditationSet.PublishedArtwork do
      description "The painting the set is shown with: its own, or else its author's portrait. Null when neither is publishable."
      public? true
    end
  end

  aggregates do
    # What `visible?` is made of. Unauthorized on purpose: the rule must
    # read every meditation in the set whoever is asking, and it answers
    # only a boolean about the set, never a meditation.
    exists :holds_meditations?, :meditations do
      authorize? false
    end

    exists :holds_archived_meditation?, :meditations do
      filter expr(not is_nil(archived_at))
      authorize? false
    end

    count :meditation_count, :meditations

    count :audio_count, :meditations do
      filter expr(has_audio?)
    end

    count :archived_count, :meditations do
      filter expr(archived?)
    end

    # What the byline derivation reads. Nils are kept: a meditation naming
    # nobody is a disagreement, not an abstention.
    list :meditation_authors, :meditations, :author do
      include_nil? true
    end

    list :meditation_sources, :meditations, :source do
      include_nil? true
    end
  end
end
