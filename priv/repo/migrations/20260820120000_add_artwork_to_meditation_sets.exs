defmodule LumenViae.Repo.Migrations.AddArtworkToMeditationSets do
  use Ecto.Migration

  def change do
    alter table(:meditation_sets) do
      # The S3 key in the public assets bucket, never a whole URL: the URL is
      # built at render time, so putting a CDN in front later is one config
      # variable and no data migration.
      add :image_key, :string
      add :image_width, :integer
      add :image_height, :integer

      # A normalized focal point, not a point offset in screen units. The same
      # painting is drawn at a 470pt hero, a 160pt card and a 40pt thumbnail;
      # an offset tuned against one of those pushes the subject out of frame in
      # the others, while "the faces are 24% down the canvas" is true at every
      # size. 0.5 reproduces today's centred fill exactly.
      add :image_focal_x, :float, null: false, default: 0.5
      add :image_focal_y, :float, null: false, default: 0.5

      add :image_alt, :text
      add :image_title, :string
      add :image_artist, :string

      # A string, not an integer: attributions are "c. 1505" and "1601-02" at
      # least as often as they are a single year.
      add :image_year, :string

      add :image_source_url, :string
      add :image_license, :string
      add :image_updated_at, :utc_datetime
    end

    create constraint(:meditation_sets, :image_focal_x_in_range,
             check: "image_focal_x >= 0.0 AND image_focal_x <= 1.0"
           )

    create constraint(:meditation_sets, :image_focal_y_in_range,
             check: "image_focal_y >= 0.0 AND image_focal_y <= 1.0"
           )
  end
end
