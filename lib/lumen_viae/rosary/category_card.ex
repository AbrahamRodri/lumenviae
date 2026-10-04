defmodule LumenViae.Rosary.CategoryCard do
  @moduledoc """
  The painting on a category's card, where it is not one of its mysteries'.

  The four Rosaries' cards show their first mystery's painting, so they
  need nothing here. The Seven Sorrows' card is Bouguereau's Pietà, which
  is no sorrow's own painting, so it has a row of its own: one per
  category slug at most, holding the artwork columns and the two actions
  that write them (`LumenViae.Rosary.Artwork.Fragment`).

  Served only inside the content document's `categories` section, as
  `card_artwork`, and only once published (alt text and a licence). No
  row is seeded: the console creates one the first time a card is saved.

  Reach category cards through `LumenViae.Rosary`; nothing outside
  `lib/lumen_viae/rosary/` names this module.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Rosary,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [LumenViae.Rosary.Artwork.Fragment]

  alias LumenViae.Rosary.Categories

  postgres do
    table "category_cards"
    repo LumenViae.Repo

    migration_types slug: :string,
                    image_key: :string,
                    image_width: :integer,
                    image_height: :integer,
                    image_title: :string,
                    image_artist: :string,
                    image_year: :string,
                    image_source_url: :string,
                    image_license: :string

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
    defaults [:read, :destroy, create: [:slug]]

    read :by_slug do
      description "A category's card, by the category's slug."
      get? true

      argument :slug, :string do
        allow_nil? false
      end

      filter expr(slug == ^arg(:slug))
    end
  end

  # Like the other resources carrying artwork: the public may read, and the
  # API serves only what is published; writing is the console's.
  policies do
    bypass LumenViae.Accounts.Checks.ActorIsAdmin do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end
  end

  validations do
    validate one_of(:slug, Categories.slugs()), message: "is not a category"
  end

  attributes do
    integer_primary_key :id

    # One of `LumenViae.Rosary.Categories.slugs/0`.
    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints max_length: 255, trim?: false
    end

    create_timestamp :inserted_at, type: :utc_datetime
    update_timestamp :updated_at, type: :utc_datetime
  end

  calculations do
    calculate :artwork, LumenViae.Rosary.Types.Artwork, LumenViae.Rosary.Artwork.Published do
      public? true
      description "The card's painting. Null until published with alt text and a licence."
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
