defmodule LumenViae.Rosary.Author do
  @moduledoc """
  A person whose writings the meditations are drawn from.

  Carries the one image that stands in for every set by this author that
  has no artwork of its own, so a portrait is uploaded once rather than
  once per set. The artwork columns are the ones `meditation_sets` carries,
  name for name.

  Mapped onto the existing `authors` table exactly as the Ecto migrations
  left it.

  Reach authors through `LumenViae.Rosary`; nothing outside
  `lib/lumen_viae/rosary/` names this module.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Rosary,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource]

  graphql do
    type :author
  end

  postgres do
    table "authors"
    repo LumenViae.Repo

    migration_types name: :string,
                    image_key: :string,
                    image_width: :integer,
                    image_height: :integer,
                    image_title: :string,
                    image_artist: :string,
                    image_year: :string,
                    image_source_url: :string,
                    image_license: :string

    migration_defaults inserted_at: "nil", updated_at: "nil"
    identity_index_names unique_name: "authors_name_index"

    check_constraints do
      check_constraint :image_focal_x, "image_focal_x_in_range",
        check: "image_focal_x >= 0.0 AND image_focal_x <= 1.0",
        message: "must be between 0.0 and 1.0"

      check_constraint :image_focal_y, "image_focal_y_in_range",
        check: "image_focal_y >= 0.0 AND image_focal_y <= 1.0",
        message: "must be between 0.0 and 1.0"
    end
  end

  actions do
    # The artwork columns are in neither accept list; they are written by
    # their own two actions, as on a meditation set.
    defaults [:read, :destroy, create: [:name], update: [:name]]
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255, trim?: false
    end

    attribute :image_key, :string do
      constraints max_length: 255
    end

    attribute :image_width, :integer
    attribute :image_height, :integer

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
    has_many :meditation_sets, LumenViae.Rosary.MeditationSet do
      destination_attribute :author_id
      public? true
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end
