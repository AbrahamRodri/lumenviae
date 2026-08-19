defmodule LumenViae.Rosary.Artwork do
  @moduledoc """
  Artwork on a meditation set: the licence vocabulary, the two changesets
  that write it, and the framing arithmetic every crop is derived from.

  A value module in the sense of `LumenViae.Rosary.Categories` and
  `LumenViae.Rosary.Labels` - no state, no queries, no schema - so the
  schema validations, the admin form and the JSON view read the same list
  and compute the same crop. Any layer may call it directly.

  ## Why there are two changesets

  Four of the columns are *managed*: `image_key`, `image_width`,
  `image_height` and `image_updated_at` are written only by
  `LumenViae.Curation.ArtworkUpload`, which has just proved the object
  exists in S3 and measured it. The rest are *editable*: a curator types
  them into the admin form. If one changeset cast both, a crafted form post
  could point a set at an arbitrary S3 key, or desync the dimensions the
  iOS hero uses to reserve its crop from the image actually stored.

  ## Why a focal point rather than a stored alignment

  The same painting is drawn at three crop sizes - a 470pt hero, a 160pt
  home card, a 40pt mini-player thumbnail - so a vertical offset in points
  can only ever be tuned for one of them. A focal point of `{0.5, 0.24}`
  says "the faces are 24% down the canvas", which is true at every size, in
  every future crop, and in CSS `object-position`. `{0.5, 0.5}` reproduces a
  centred fill exactly and `{0.5, 0.0}` reproduces top alignment, so nothing
  is lost by moving to it.
  """

  import Ecto.Changeset

  @licenses [
    {"Public domain", "public_domain"},
    {"CC0", "cc0"},
    {"CC BY", "cc_by"},
    {"CC BY-SA", "cc_by_sa"},
    {"Licensed", "licensed"},
    {"Unknown", "unknown"}
  ]

  @license_slugs Enum.map(@licenses, fn {_label, slug} -> slug end)

  # Written only by ArtworkUpload, after the object is in S3.
  @managed_fields ~w(image_key image_width image_height image_updated_at)a

  # Written by the admin form.
  @editable_fields ~w(image_focal_x image_focal_y image_alt image_title
                      image_artist image_year image_source_url image_license)a

  # Blank in a form means "not filled in", not "the empty string". The
  # publish gate in the API asks whether alt text and a licence are present,
  # and a stray space must not be able to satisfy it.
  @trimmed_fields ~w(image_alt image_title image_artist image_year
                     image_source_url image_license)a

  @doc """
  Returns `{label, slug}` licence pairs in display order, for form selects.
  """
  def license_options, do: @licenses

  @doc """
  Returns just the licence slugs, for changeset validation.
  """
  def licenses, do: @license_slugs

  @doc """
  Returns the display label for a licence slug, falling back to the slug so
  an unrecognised value renders as something rather than blank.
  """
  def license_label(slug) do
    case List.keyfind(@licenses, slug, 1) do
      {label, ^slug} -> label
      nil -> slug
    end
  end

  @doc """
  Changeset for a completed upload: the four managed fields, plus any
  metadata supplied in the same breath.
  """
  def cast_upload(struct, attrs) do
    struct
    |> cast(attrs, @managed_fields ++ @editable_fields)
    |> validate()
  end

  @doc """
  Changeset for the admin form: metadata only. `image_key` and the
  dimensions are not castable here at any price.
  """
  def cast_metadata(struct, attrs) do
    struct
    |> cast(attrs, @editable_fields)
    |> validate()
  end

  @doc """
  Whether artwork is complete enough to be served.

  Alt text and a licence are a publish gate rather than a save gate: the
  changesets above require neither, because `ArtworkUpload.upload/3` returns
  only the managed fields and the first upload on a set would otherwise be
  invalid before the curator could describe it. Artwork with no description
  and no provenance simply is not served, which protects any future entry
  point too.
  """
  def publishable?(%{image_key: key, image_alt: alt, image_license: license})
      when is_binary(key) and is_binary(alt) and is_binary(license),
      do: key != "" and alt != "" and license != ""

  def publishable?(_record), do: false

  @doc """
  The coarse `"top" | "center" | "bottom"` the iOS request asked for,
  derived from `image_focal_y` rather than stored beside it, so the two can
  never disagree.
  """
  def alignment(nil), do: nil
  def alignment(focal_y) when focal_y < 1 / 3, do: "top"
  def alignment(focal_y) when focal_y > 2 / 3, do: "bottom"
  def alignment(_focal_y), do: "center"

  @doc """
  The focal point as a CSS `object-position` value, so the admin preview
  frames a painting exactly the way the phone will.

      iex> LumenViae.Rosary.Artwork.object_position(0.5, 0.24)
      "50.0% 24.0%"
  """
  def object_position(focal_x, focal_y) do
    "#{percent(focal_x)}% #{percent(focal_y)}%"
  end

  defp percent(nil), do: 50.0
  defp percent(value), do: Float.round(value * 100, 1)

  @doc """
  How to draw an image of intrinsic size `intrinsic` inside crop frame
  `frame`, filling the frame and keeping the focal point as near its centre
  as the overflow allows.

      scale  = max(F.w / I.w, F.h / I.h)
      drawn  = (I.w * scale, I.h * scale)
      offset = ((0.5 - f.x) * (drawn.w - F.w), (0.5 - f.y) * (drawn.h - F.h))

  Both arguments are `{width, height}` and the focal point is `{x, y}` in
  0..1. Returns the scale, the drawn size and the offset to translate by, in
  the frame's own units. A focal point of `{0.5, 0.5}` always returns a zero
  offset, which is the centred fill the app draws today.
  """
  def crop({intrinsic_w, intrinsic_h}, {frame_w, frame_h}, {focal_x, focal_y})
      when intrinsic_w > 0 and intrinsic_h > 0 do
    scale = max(frame_w / intrinsic_w, frame_h / intrinsic_h)
    drawn_w = intrinsic_w * scale
    drawn_h = intrinsic_h * scale

    %{
      scale: scale,
      width: drawn_w,
      height: drawn_h,
      offset_x: (0.5 - focal_x) * (drawn_w - frame_w),
      offset_y: (0.5 - focal_y) * (drawn_h - frame_h)
    }
  end

  defp validate(changeset) do
    changeset
    |> trim_blank_strings()
    # A backstop for an explicit null only: Ecto replaces a blank form value
    # with the field's default, so an empty focal input arrives here as 0.5.
    |> validate_required([:image_focal_x, :image_focal_y])
    |> validate_number(:image_focal_x,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:image_focal_y,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:image_width, greater_than: 0)
    |> validate_number(:image_height, greater_than: 0)
    |> validate_inclusion(:image_license, @license_slugs,
      message: "is not one of the licences this project records"
    )
    |> validate_format(:image_source_url, ~r{^https?://},
      message: "must start with http:// or https://"
    )
    |> check_constraint(:image_focal_x,
      name: :image_focal_x_in_range,
      message: "must be between 0.0 and 1.0"
    )
    |> check_constraint(:image_focal_y,
      name: :image_focal_y_in_range,
      message: "must be between 0.0 and 1.0"
    )
  end

  defp trim_blank_strings(changeset) do
    Enum.reduce(@trimmed_fields, changeset, fn field, acc ->
      update_change(acc, field, fn
        value when is_binary(value) ->
          case String.trim(value) do
            "" -> nil
            trimmed -> trimmed
          end

        value ->
          value
      end)
    end)
  end
end
