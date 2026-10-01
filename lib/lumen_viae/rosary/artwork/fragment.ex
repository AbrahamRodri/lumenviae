defmodule LumenViae.Rosary.Artwork.Fragment do
  @moduledoc """
  Everything a resource needs in order to carry artwork: the columns, the
  two actions that write them, and the validations both actions share.

  A resource takes it with `use Ash.Resource, fragments: [...]`, so a
  meditation set's painting and an author's portrait are the same thirteen
  columns, written through the same two doors, and cannot drift apart.

  ## Why there are two actions

  Four of the columns are *managed*: `image_key`, `image_width`,
  `image_height` and `image_updated_at` are written only by
  `LumenViae.Curation.ArtworkUpload`, which has just proved the object
  exists in S3 and measured it. The rest are *editable*: a curator types
  them into the admin form. If one action accepted both, a crafted form
  post could point a record at an arbitrary S3 key, or desync the
  dimensions the iOS hero uses to reserve its crop from the image actually
  stored.

    * `:record_artwork` records a completed upload: the managed fields,
      plus any metadata supplied in the same breath.
    * `:update_artwork_metadata` records what the curator typed. The key
      and the dimensions are not among its inputs at any price.

  Neither list is accepted by a resource's ordinary create or update.

  Alt text and a licence are a publish gate rather than a save gate (see
  `LumenViae.Rosary.Artwork.publishable?/1`), so neither action requires
  them.

  The check constraints and column types stay in each resource's own
  `postgres` block, because they belong to that resource's table.
  """
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias LumenViae.Rosary.Artwork

  actions do
    update :record_artwork do
      description "Records a completed upload: the key and dimensions just proved, plus any metadata."
      accept Artwork.managed_fields() ++ Artwork.editable_fields()
    end

    update :update_artwork_metadata do
      description "Records the artwork details a curator typed. Cannot touch the key or the dimensions."
      accept Artwork.editable_fields()
    end
  end

  # Each rule applies to a value being written, never to one already
  # stored, so an old row that would fail a newer rule can still have its
  # other fields edited.
  validations do
    validate numericality(:image_focal_x,
               greater_than_or_equal_to: 0.0,
               less_than_or_equal_to: 1.0
             ),
             where: [changing(:image_focal_x)],
             message: "must be between 0.0 and 1.0"

    validate numericality(:image_focal_y,
               greater_than_or_equal_to: 0.0,
               less_than_or_equal_to: 1.0
             ),
             where: [changing(:image_focal_y)],
             message: "must be between 0.0 and 1.0"

    validate numericality(:image_width, greater_than: 0), where: [changing(:image_width)]
    validate numericality(:image_height, greater_than: 0), where: [changing(:image_height)]

    validate one_of(:image_license, Artwork.licenses()),
      where: [changing(:image_license)],
      message: "is not one of the licences this project records"

    validate match(:image_source_url, ~r{^https?://}),
      where: [changing(:image_source_url)],
      message: "must start with http:// or https://"
  end

  attributes do
    # The S3 key in the public assets bucket, never a whole URL: the URL is
    # built at render time, so putting a CDN in front later is one config
    # variable and no data migration.
    attribute :image_key, :string do
      constraints max_length: 255
    end

    attribute :image_width, :integer
    attribute :image_height, :integer

    # A normalized focal point, not a point offset in screen units. The same
    # painting is drawn at a 470pt hero, a 160pt card and a 40pt thumbnail;
    # an offset tuned against one of those pushes the subject out of frame
    # in the others, while "the faces are 24% down the canvas" is true at
    # every size. 0.5 reproduces a centred fill exactly.
    #
    # Floats, not decimals: a decimal is encoded as a JSON string, which
    # the iOS app's `Double?` cannot decode.
    attribute :image_focal_x, :float do
      allow_nil? false
      default 0.5
    end

    attribute :image_focal_y, :float do
      allow_nil? false
      default 0.5
    end

    # Blank in a form means "not filled in", not "the empty string", so the
    # text fields below are trimmed and an empty one is stored as null. The
    # publish gate asks whether alt text and a licence are present, and a
    # stray space must not be able to satisfy it.
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
  end
end
