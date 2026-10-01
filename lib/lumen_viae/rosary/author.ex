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
    extensions: [AshGraphql.Resource, AshPaperTrail.Resource],
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
  end

  actions do
    # The artwork columns are in neither accept list; they are written by
    # the fragment's two actions.
    defaults [:read, :destroy, create: [:name]]

    update :update do
      primary? true
      accept [:name]

      # As on Mystery: non-atomic, so a save that changed nothing writes no
      # version.
      require_atomic? false
    end

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

  aggregates do
    # What the authors list shows beside each portrait: how many sets it
    # is covering.
    count :meditation_set_count, :meditation_sets
  end

  identities do
    identity :unique_name, [:name]
  end
end
