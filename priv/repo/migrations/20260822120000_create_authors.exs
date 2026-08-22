defmodule LumenViae.Repo.Migrations.CreateAuthors do
  use Ecto.Migration

  def change do
    create table(:authors) do
      add :name, :string, null: false

      # The same artwork columns meditation_sets carry, name for name, so
      # the portrait goes through Rosary.Artwork's changesets and
      # ArtworkUpload unchanged.
      add :image_key, :string
      add :image_width, :integer
      add :image_height, :integer
      add :image_focal_x, :float, null: false, default: 0.5
      add :image_focal_y, :float, null: false, default: 0.5
      add :image_alt, :text
      add :image_title, :string
      add :image_artist, :string
      add :image_year, :string
      add :image_source_url, :string
      add :image_license, :string
      add :image_updated_at, :utc_datetime

      timestamps()
    end

    create unique_index(:authors, [:name])

    create constraint(:authors, :image_focal_x_in_range,
             check: "image_focal_x >= 0.0 AND image_focal_x <= 1.0"
           )

    create constraint(:authors, :image_focal_y_in_range,
             check: "image_focal_y >= 0.0 AND image_focal_y <= 1.0"
           )
  end
end
