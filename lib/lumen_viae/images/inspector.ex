defmodule LumenViae.Images.Inspector do
  @moduledoc """
  Reads an image's format and dimensions straight out of its header.

  The production image carries no image library - the Dockerfile runner
  installs `libstdc++6 openssl libncurses5 locales ca-certificates` and
  nothing else - so nothing can be decoded, resized or re-encoded on the
  server. Validation is the whole job, and validation only needs the first
  few dozen bytes of the file, which is why this is header pattern matching
  with no dependency rather than a port to ImageMagick.

  Infrastructure, like `storage/` and `audio/`: it knows nothing about the
  domain and holds no opinion about which images are acceptable. The rules
  live in `LumenViae.Curation.ArtworkUpload`.
  """

  # The parser's entry point is `inspect/1`, which is also a Kernel import.
  import Kernel, except: [inspect: 1]

  @type info :: %{
          format: :jpeg | :png,
          width: pos_integer,
          height: pos_integer,
          components: pos_integer,
          orientation: 1..8
        }

  # SOF0..SOF15 carry the frame header this is looking for. 0xC4 (define
  # Huffman tables), 0xC8 (JPEG extensions) and 0xCC (define arithmetic
  # coding) sit inside that numeric range and are not frames - reading
  # dimensions out of one of those is the classic way this parser goes wrong.
  @frame_markers Enum.to_list(0xC0..0xCF) -- [0xC4, 0xC8, 0xCC]

  # Markers that stand alone: no length field, no payload to skip.
  @standalone_markers [0x01 | Enum.to_list(0xD0..0xD7)]

  # APP1, where a camera or an editor puts the Exif block and with it the
  # orientation tag.
  @app1 0xE1

  # The Exif orientation tag, and the values (5 to 8) that turn the picture
  # a quarter turn, so that it is shown with its width and height swapped.
  @orientation_tag 0x0112
  @quarter_turns 5..8

  # Markers that end the header chain. Entropy-coded scan data follows SOS,
  # so a file that reaches it without a frame header has none.
  @terminal_markers [0xD8, 0xD9, 0xDA]

  @doc """
  Returns the format, dimensions and channel count of an image.

  The dimensions are the picture's as it is shown, not as it is stored: a
  JPEG whose Exif orientation is a quarter turn (5 to 8) is drawn by every
  browser with its width and height swapped, and so is reported that way,
  the same geometry `LumenViae.Images.Variants` resizes after applying the
  orientation. `orientation` is the tag itself, 1 when there is none.

  `components` is the channel count of the encoded data: 3 for ordinary RGB
  JPEG, 1 for greyscale, 4 for CMYK. It is the only way to spot a CMYK
  JPEG, which iOS renders with visibly shifted colour.

  Returns `{:error, :unsupported_format}` when the bytes are not a JPEG or
  a PNG at all, and `{:error, :malformed}` when they claim to be one but
  the header does not parse - a truncated upload, or a frame header that
  never arrives.

  ## Examples

      iex> LumenViae.Images.Inspector.inspect(File.read!("painting.jpg"))
      {:ok, %{format: :jpeg, width: 1600, height: 2400, components: 3, orientation: 1}}

      iex> LumenViae.Images.Inspector.inspect("not an image")
      {:error, :unsupported_format}
  """
  @spec inspect(binary) :: {:ok, info} | {:error, :unsupported_format | :malformed}
  def inspect(binary)

  # PNG: the signature is followed immediately by IHDR, which is the whole
  # header. There is no chain to walk.
  def inspect(
        <<137, 80, 78, 71, 13, 10, 26, 10, _chunk_length::32, "IHDR", width::32, height::32,
          _bit_depth::8, color_type::8, _rest::binary>>
      ) do
    case png_components(color_type) do
      nil -> {:error, :malformed}
      components -> build(:png, width, height, components, 1)
    end
  end

  def inspect(<<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>>), do: {:error, :malformed}

  # JPEG: SOI, then a chain of marker segments to walk until a frame header.
  def inspect(<<0xFF, 0xD8, rest::binary>>), do: scan_jpeg(rest, 1)

  def inspect(binary) when is_binary(binary), do: {:error, :unsupported_format}

  # Any number of 0xFF fill bytes may pad the gap before a marker. The
  # orientation found in an APP1 segment on the way is carried to the frame
  # header.
  defp scan_jpeg(<<0xFF, 0xFF, rest::binary>>, orientation),
    do: scan_jpeg(<<0xFF, rest::binary>>, orientation)

  defp scan_jpeg(<<0xFF, marker, length::16, rest::binary>>, orientation)
       when marker in @frame_markers do
    payload_size = length - 2

    case rest do
      # The declared payload has to be there in full, not just the six bytes
      # the dimensions occupy: a file cut short inside its own frame segment
      # would otherwise yield plausible dimensions for an image nobody can
      # decode, and be uploaded as if it were sound.
      <<_precision::8, height::16, width::16, components::8, _tail::binary>>
      when payload_size >= 6 and byte_size(rest) >= payload_size ->
        build(:jpeg, width, height, components, orientation)

      _truncated ->
        {:error, :malformed}
    end
  end

  defp scan_jpeg(<<0xFF, marker, rest::binary>>, orientation)
       when marker in @standalone_markers,
       do: scan_jpeg(rest, orientation)

  defp scan_jpeg(<<0xFF, marker, length::16, rest::binary>>, orientation)
       when marker not in @terminal_markers and length >= 2 do
    payload_size = length - 2

    case rest do
      <<payload::binary-size(payload_size), tail::binary>> ->
        orientation =
          if marker == @app1, do: exif_orientation(payload) || orientation, else: orientation

        scan_jpeg(tail, orientation)

      _truncated ->
        {:error, :malformed}
    end
  end

  defp scan_jpeg(_no_frame_header, _orientation), do: {:error, :malformed}

  # An Exif APP1 payload: "Exif\0\0", then a TIFF header naming its byte
  # order and where the first directory (IFD0, the picture's own tags)
  # starts. Anything that does not parse is no orientation at all, rather
  # than a malformed image: the picture itself is still sound.
  defp exif_orientation(<<"Exif", 0, 0, tiff::binary>>) do
    with {:ok, endian} <- tiff_endian(tiff),
         {:ok, ifd} <- ifd_offset(tiff, endian),
         <<_skip::binary-size(ifd), count::binary-size(2), entries::binary>> <- tiff do
      find_orientation(entries, uint(count, endian), endian)
    else
      _unreadable -> nil
    end
  end

  defp exif_orientation(_other_app1), do: nil

  defp tiff_endian(<<"II", 42, 0, _rest::binary>>), do: {:ok, :little}
  defp tiff_endian(<<"MM", 0, 42, _rest::binary>>), do: {:ok, :big}
  defp tiff_endian(_unknown), do: :error

  defp ifd_offset(<<_header::binary-size(4), offset::binary-size(4), _rest::binary>>, endian),
    do: {:ok, uint(offset, endian)}

  defp ifd_offset(_short, _endian), do: :error

  # Each directory entry is twelve bytes: tag, type, count, then the value
  # itself when it fits, as a SHORT orientation always does.
  defp find_orientation(_entries, 0, _endian), do: nil

  defp find_orientation(
         <<tag::binary-size(2), _type::binary-size(2), _count::binary-size(4),
           value::binary-size(2), _pad::binary-size(2), rest::binary>>,
         remaining,
         endian
       ) do
    if uint(tag, endian) == @orientation_tag do
      case uint(value, endian) do
        orientation when orientation in 1..8 -> orientation
        _invalid -> nil
      end
    else
      find_orientation(rest, remaining - 1, endian)
    end
  end

  defp find_orientation(_truncated, _remaining, _endian), do: nil

  defp uint(bytes, :little), do: :binary.decode_unsigned(bytes, :little)
  defp uint(bytes, :big), do: :binary.decode_unsigned(bytes, :big)

  # PNG stores a colour type rather than a channel count. Indexed images are
  # one byte per pixel on the wire whatever their palette holds.
  defp png_components(0), do: 1
  defp png_components(2), do: 3
  defp png_components(3), do: 1
  defp png_components(4), do: 2
  defp png_components(6), do: 4
  defp png_components(_unknown), do: nil

  defp build(format, width, height, components, orientation)
       when width > 0 and height > 0 and components > 0 do
    {shown_width, shown_height} =
      if orientation in @quarter_turns, do: {height, width}, else: {width, height}

    {:ok,
     %{
       format: format,
       width: shown_width,
       height: shown_height,
       components: components,
       orientation: orientation
     }}
  end

  defp build(_format, _width, _height, _components, _orientation), do: {:error, :malformed}
end
