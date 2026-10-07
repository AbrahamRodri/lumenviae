defmodule LumenViae.Images.Variants do
  @moduledoc """
  The smaller WebP copies of an uploaded painting that the public site
  draws, so a phone never downloads a 4000px original to fill a 160px card.

  Infrastructure, like `LumenViae.Images.Inspector`: it turns JPEG bytes
  into WebP bytes and names the keys they live at, and knows nothing about
  the domain. `LumenViae.Curation.ArtworkUpload` decides when to make them.

  ## What a variant is

    * One of `widths/0`, and only those narrower than the original: an
      upscale would be larger and no sharper, so it is never made.
    * Resized with a lanczos3 kernel (libvips' high-quality default, named
      here so it cannot drift), aspect ratio kept.
    * Turned the way the original is shown: EXIF orientation is applied
      before the metadata goes, because a browser rotates a JPEG by its tag
      and would draw an untagged copy on its side.
    * Converted to sRGB when the original carries another profile, then
      saved as WebP at quality 85 with smart chroma subsampling (sharp red
      and blue edges in a painting) and every piece of metadata but the
      ICC profile stripped.

  ## Keys

  `sets/27/8f21c4d9e0b3a7f6.jpg` has variants at
  `sets/27/8f21c4d9e0b3a7f6-480.webp` and so on. The original's key is
  content-addressed, so a variant's is too, and the year-long immutable
  cache header on the bucket holds for both.
  """

  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  @widths [480, 960, 1600]
  @quality 85

  @doc "Every width a variant may be made at, narrowest first."
  @spec widths() :: [pos_integer]
  def widths, do: @widths

  @doc """
  The widths an original `original_width` pixels wide gets: those strictly
  narrower than it.

      iex> LumenViae.Images.Variants.widths_for(1200)
      [480, 960]
  """
  @spec widths_for(pos_integer) :: [pos_integer]
  def widths_for(original_width) when is_integer(original_width) do
    Enum.filter(@widths, &(&1 < original_width))
  end

  @doc """
  The key a variant of `original_key` at `width` lives at.

      iex> LumenViae.Images.Variants.key("sets/27/8f21c4d9e0b3a7f6.jpg", 960)
      "sets/27/8f21c4d9e0b3a7f6-960.webp"
  """
  @spec key(String.t(), pos_integer) :: String.t()
  def key(original_key, width) when is_binary(original_key) and is_integer(width) do
    Path.rootname(original_key) <> "-#{width}.webp"
  end

  @doc """
  Makes every variant `binary` gets, as `{:ok, [{width, webp_bytes}]}`
  narrowest first, or `{:error, reason}` when the bytes cannot be decoded.

  The original is decoded once and every width resized from it.
  """
  @spec generate(binary) :: {:ok, [{pos_integer, binary}]} | {:error, term}
  def generate(binary) when is_binary(binary) do
    with {:ok, image} <- Image.new_from_buffer(binary),
         {:ok, image} <- upright(image),
         {:ok, image} <- to_srgb(image) do
      image
      |> Image.width()
      |> widths_for()
      |> Enum.reduce_while({:ok, []}, fn width, {:ok, acc} ->
        case encode(image, width) do
          {:ok, webp} -> {:cont, {:ok, [{width, webp} | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, variants} -> {:ok, Enum.reverse(variants)}
        error -> error
      end
    end
  end

  defp upright(image) do
    case Operation.autorot(image) do
      {:ok, {rotated, _flags}} -> {:ok, rotated}
      {:error, reason} -> {:error, reason}
    end
  end

  defp to_srgb(image) do
    {:ok, fields} = Image.header_field_names(image)

    if "icc-profile-data" in fields do
      Operation.icc_transform(image, "srgb", embedded: true, intent: :VIPS_INTENT_PERCEPTUAL)
    else
      {:ok, image}
    end
  end

  defp encode(image, width) do
    with {:ok, resized} <-
           Operation.resize(image, width / Image.width(image), kernel: :VIPS_KERNEL_LANCZOS3) do
      Operation.webpsave_buffer(resized,
        Q: @quality,
        smart_subsample: true,
        keep: [:VIPS_FOREIGN_KEEP_ICC]
      )
    end
  end
end
