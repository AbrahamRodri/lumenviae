defmodule LumenViae.Rosary.Author do
  @moduledoc """
  A person whose writings the meditations are drawn from.

  Carries the one image that stands in for every set by this author that
  has no artwork of its own, so a portrait is uploaded once rather than
  once per set. The artwork columns, and the two actions that write them,
  come from `LumenViae.Rosary.Artwork.Fragment`: they are the ones a
  meditation set carries, name for name, so the portrait goes through
  `LumenViae.Curation.ArtworkUpload` unchanged.

  Deleting an author does not delete or hide their sets. The foreign key
  clears the link, and each set falls back to its own artwork and byline.

  Mapped onto the existing `authors` table exactly as the Ecto migrations
  left it.

  Reach authors through `LumenViae.Rosary`; nothing outside
  `lib/lumen_viae/rosary/` names this module.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Rosary,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource],
    fragments: [LumenViae.Rosary.Artwork.Fragment]

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
    # the fragment's two actions.
    defaults [:read, :destroy, create: [:name], update: [:name]]

    read :alphabetical do
      description "Every author, by name."
      prepare build(sort: [name: :asc])
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255, trim?: false
    end

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
