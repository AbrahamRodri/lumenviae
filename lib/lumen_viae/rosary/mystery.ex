defmodule LumenViae.Rosary.Mystery do
  @moduledoc """
  One of the mysteries of the Rosary.

  Mapped onto the existing `mysteries` table exactly as the Ecto migrations
  left it: integer ids, second-precision naive timestamps, `varchar(255)`
  where the column was an Ecto `:string`.

  ## Artwork

  A mystery's painting is the artwork columns and the two actions that
  write them, from `LumenViae.Rosary.Artwork.Fragment`, as a set's and an
  author's are. It is served as `artwork` once it can be published (alt
  text and a licence), and as null until then.

  Reach mysteries through `LumenViae.Rosary`; nothing outside
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

  # Reached in GraphQL only as a meditation's mystery. None of its
  # relationships is shown: its meditations include ones in no public set.
  # days_prayed is left out too: it carries an older schedule the app no
  # longer reads, and REST keeps it only for builds that still decode it.
  graphql do
    type :mystery
    relationships []
    hide_fields [:days_prayed]
    derive_filter? false
    derive_sort? false
  end

  # As in GraphQL: no relationships, and not days_prayed. `key` is a
  # calculation, which AshJsonApi serves only as a default field, so every
  # shown field is named a default.
  json_api do
    type "mystery"

    default_fields [
      :key,
      :name,
      :category,
      :order,
      :description,
      :scripture_reference,
      :fruit,
      :key_verse,
      :key_verse_reference,
      :artwork
    ]

    show_fields [
      :key,
      :name,
      :category,
      :order,
      :description,
      :scripture_reference,
      :fruit,
      :key_verse,
      :key_verse_reference,
      :artwork
    ]

    derive_filter? false
    derive_sort? false
  end

  postgres do
    table "mysteries"
    repo LumenViae.Repo

    # Ash would make an :integer attribute a bigint; `order` is an int4.
    migration_types name: :string,
                    category: :string,
                    order: :integer,
                    days_prayed: :string,
                    fruit: :string,
                    key_verse_reference: :string,
                    image_key: :string,
                    image_width: :integer,
                    image_height: :integer,
                    image_title: :string,
                    image_artist: :string,
                    image_year: :string,
                    image_source_url: :string,
                    image_license: :string

    migration_defaults inserted_at: "nil", updated_at: "nil"
    identity_index_names unique_order_in_category: "mysteries_category_order_index"

    custom_indexes do
      index [:category]
    end

    check_constraints do
      check_constraint :image_focal_x, "image_focal_x_in_range",
        check: "image_focal_x >= 0.0 AND image_focal_x <= 1.0",
        message: "must be between 0.0 and 1.0"

      check_constraint :image_focal_y, "image_focal_y_in_range",
        check: "image_focal_y >= 0.0 AND image_focal_y <= 1.0",
        message: "must be between 0.0 and 1.0"
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
    reference_source? false

    # Which admin made the change: the actor of the action, when it is one.
    # Nil for an operator's shell (mix tasks, LumenViae.Release), which runs
    # with no actor, and for rows written before this was recorded.
    belongs_to_actor :admin, LumenViae.Accounts.Admin, domain: LumenViae.Accounts

    # Admin-only, read-only history. See LumenViae.Rosary.VersionPolicies.
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin LumenViae.Rosary.VersionPolicies
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [
        :name,
        :category,
        :order,
        :days_prayed,
        :description,
        :scripture_reference,
        :fruit,
        :key_verse,
        :key_verse_reference
      ]
    ]

    update :update do
      primary? true

      accept [
        :name,
        :category,
        :order,
        :days_prayed,
        :description,
        :scripture_reference,
        :fruit,
        :key_verse,
        :key_verse_reference
      ]

      # With the record in hand the paper trail can tell an edit from a save
      # that changed nothing, and writes no version for the latter. An
      # atomic update never reads the row, so it could not.
      require_atomic? false
    end

    read :in_prayer_order do
      description "Every mystery in the order they are prayed: by category, then by position within the category."
      prepare build(sort: [category: :asc, order: :asc])
    end

    read :by_category do
      description "One category's mysteries, in the order they are prayed."

      argument :category, :string do
        allow_nil? false
      end

      filter expr(category == ^arg(:category))
      prepare build(sort: [order: :asc])
    end
  end

  # The mysteries are the Rosary's fixed text, all of it public: the site
  # and both APIs list every one. Writing is the console's.
  policies do
    bypass LumenViae.Accounts.Checks.ActorIsAdmin do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end
  end

  validations do
    validate one_of(:category, Categories.slugs()), message: "is invalid"
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255, trim?: false
    end

    # One of `LumenViae.Rosary.Categories.slugs/0`. A plain string, because
    # the API serialises it as one and the iOS app matches it exactly.
    attribute :category, :string do
      allow_nil? false
      public? true
      constraints max_length: 255, trim?: false
    end

    attribute :order, :integer do
      allow_nil? false
      public? true
    end

    # A string or null, never a list: "Monday, Saturday" is what the app
    # decodes.
    attribute :days_prayed, :string do
      public? true
      constraints max_length: 255, trim?: false
    end

    attribute :description, :string do
      public? true
      constraints trim?: false
    end

    attribute :scripture_reference, :string do
      public? true
      constraints trim?: false
    end

    # The grace the mystery is prayed for: "Humility". The app's
    # MysteryData.traditionalFruits, keyed the same way.
    attribute :fruit, :string do
      public? true
      constraints max_length: 255, trim?: false
    end

    # The one verse to carry into the decade, in the Douay-Rheims, and its
    # citation: the app's MysteriesInScriptureData.keyVerses, split where
    # the app splits them. Served as written; the Scriptural Rosary's bead
    # verses are another rendering and are not made to agree with it.
    attribute :key_verse, :string do
      public? true
      constraints trim?: false
    end

    attribute :key_verse_reference, :string do
      public? true
      constraints max_length: 255, trim?: false
    end

    create_timestamp :inserted_at, type: :naive_datetime
    update_timestamp :updated_at, type: :naive_datetime
  end

  relationships do
    has_many :meditations, LumenViae.Rosary.Meditation do
      public? true
    end

    # The meditations a reader can be shown: archived ones are out of
    # circulation everywhere but the admin.
    has_many :active_meditations, LumenViae.Rosary.Meditation do
      filter expr(is_nil(archived_at))
      public? true
    end
  end

  calculations do
    calculate :artwork, LumenViae.Rosary.Types.Artwork, LumenViae.Rosary.Artwork.Published do
      public? true

      description "The mystery's painting, with its attribution. Null until one is uploaded and published with alt text and a licence."
    end

    calculate :key, :string, expr(category <> "_" <> type(order, :string)) do
      public? true
      allow_nil? false

      description "The app's key for the mystery, `<category>_<order>`: `joyful_1`. Every section of the Rosary's content that is keyed by a mystery uses it; the id is the server's and differs between databases."
    end
  end

  aggregates do
    count :meditation_count, :meditations

    # A mystery whose only meditation has been archived has nothing to
    # pray, so the dashboard's health check asks this one.
    count :active_meditation_count, :active_meditations
  end

  identities do
    identity :unique_order_in_category, [:category, :order]
  end
end
