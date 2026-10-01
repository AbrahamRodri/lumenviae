defmodule LumenViae.Rosary.MeditationSet do
  @moduledoc """
  A curated collection of meditations prayed together as one Rosary.

  Mapped onto the existing `meditation_sets` table exactly as the Ecto
  migrations left it.

  Reach sets through `LumenViae.Rosary`; nothing outside
  `lib/lumen_viae/rosary/` names this module.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Rosary,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource]

  graphql do
    type :meditation_set
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

  actions do
    # The artwork columns are in neither accept list. They are written by
    # their own two actions, for the same reason archived_at is not
    # writable on a meditation.
    defaults [
      :read,
      :destroy,
      create: [:name, :category, :description, :labels, :author, :source, :author_id],
      update: [:name, :category, :description, :labels, :author, :source, :author_id]
    ]
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255, trim?: false
    end

    # One of `LumenViae.Rosary.Categories.slugs/0`.
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

    # Artwork. The S3 key in the public assets bucket, never a whole URL:
    # the URL is built at render time, so putting a CDN in front later is
    # one config variable and no data migration.
    attribute :image_key, :string do
      constraints max_length: 255
    end

    attribute :image_width, :integer
    attribute :image_height, :integer

    # A normalized focal point, not a point offset in screen units. Floats,
    # not decimals: a decimal is encoded as a JSON string, which the iOS
    # app's `Double?` cannot decode.
    attribute :image_focal_x, :float do
      allow_nil? false
      default 0.5
    end

    attribute :image_focal_y, :float do
      allow_nil? false
      default 0.5
    end

    attribute :image_alt, :string

    attribute :image_title, :string do
      constraints max_length: 255
    end

    attribute :image_artist, :string do
      constraints max_length: 255
    end

    # A string, not an integer: attributions are "c. 1505" and "1601-02" at
    # least as often as they are a single year.
    attribute :image_year, :string do
      constraints max_length: 255
    end

    attribute :image_source_url, :string do
      constraints max_length: 255
    end

    attribute :image_license, :string do
      constraints max_length: 255
    end

    attribute :image_updated_at, :utc_datetime

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

    has_many :set_memberships, LumenViae.Rosary.SetMembership do
      public? true
    end

    many_to_many :meditations, LumenViae.Rosary.Meditation do
      through LumenViae.Rosary.SetMembership
      join_relationship :set_memberships
      source_attribute_on_join_resource :meditation_set_id
      destination_attribute_on_join_resource :meditation_id
      public? true
    end

    has_many :completions, LumenViae.Rosary.Completion
  end
end
