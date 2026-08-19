defmodule LumenViae.Images.InspectorTest do
  use ExUnit.Case, async: true

  import Kernel, except: [inspect: 1]

  alias LumenViae.Images.Inspector

  # Two images already checked into the repo, so the parser is proved against
  # files a real encoder wrote and not only against ones this test builds.
  @real_jpeg "priv/static/images/carlo-acutis.jpg"
  @real_png "priv/static/images/pngs/deo-gratias.png"

  defp jpeg(segments), do: <<0xFF, 0xD8>> <> IO.iodata_to_binary(segments)

  defp segment(marker, payload),
    do: <<0xFF, marker, byte_size(payload) + 2::16>> <> payload

  # A frame header: precision, height, width, component count, then three
  # bytes of sampling detail per component that nothing here reads.
  defp frame(marker, width, height, components) do
    segment(
      marker,
      <<8, height::16, width::16, components::8>> <> :binary.copy(<<1, 0x11, 0>>, components)
    )
  end

  describe "inspect/1 on real files" do
    test "reads a JPEG written by a real encoder, walking past its EXIF segment" do
      assert {:ok, info} = Inspector.inspect(File.read!(@real_jpeg))
      assert info == %{format: :jpeg, width: 390, height: 510, components: 3}
    end

    test "reads a PNG written by a real encoder" do
      assert {:ok, info} = Inspector.inspect(File.read!(@real_png))
      assert info == %{format: :png, width: 474, height: 266, components: 4}
    end
  end

  describe "inspect/1 on JPEG" do
    test "reads dimensions from a baseline frame header" do
      binary = jpeg([segment(0xE0, "JFIF\0"), frame(0xC0, 1600, 2400, 3)])

      assert Inspector.inspect(binary) ==
               {:ok, %{format: :jpeg, width: 1600, height: 2400, components: 3}}
    end

    test "reads dimensions from a progressive frame header" do
      binary = jpeg([frame(0xC2, 1200, 1800, 3)])

      assert {:ok, %{width: 1200, height: 1800}} = Inspector.inspect(binary)
    end

    test "reports four components for a CMYK JPEG" do
      binary = jpeg([frame(0xC0, 1600, 2400, 4)])

      assert {:ok, %{components: 4}} = Inspector.inspect(binary)
    end

    test "reports one component for a greyscale JPEG" do
      binary = jpeg([frame(0xC0, 1600, 2400, 1)])

      assert {:ok, %{components: 1}} = Inspector.inspect(binary)
    end

    # 0xC4, 0xC8 and 0xCC sit inside the SOF0..SOF15 range and are not frames.
    # Their payloads are shaped so that misreading one would report 4096x256.
    for {marker, name} <- [{0xC4, "DHT"}, {0xC8, "JPG"}, {0xCC, "DAC"}] do
      test "does not mistake a #{name} segment for a frame header" do
        decoy = <<8, 256::16, 4096::16, 9::8, 0, 0, 0, 0>>
        binary = jpeg([segment(unquote(marker), decoy), frame(0xC0, 1600, 2400, 3)])

        assert Inspector.inspect(binary) ==
                 {:ok, %{format: :jpeg, width: 1600, height: 2400, components: 3}}
      end
    end

    test "skips a standalone marker that carries no length" do
      binary = jpeg([<<0xFF, 0x01>>, frame(0xC0, 1600, 2400, 3)])

      assert {:ok, %{width: 1600}} = Inspector.inspect(binary)
    end

    test "tolerates fill bytes before a marker" do
      binary = jpeg([<<0xFF, 0xFF, 0xFF>>, frame(0xC0, 1600, 2400, 3)])

      assert {:ok, %{width: 1600}} = Inspector.inspect(binary)
    end

    test "walks past a long segment to reach the frame header" do
      binary = jpeg([segment(0xE1, :binary.copy(<<0>>, 60_000)), frame(0xC0, 1600, 2400, 3)])

      assert {:ok, %{width: 1600}} = Inspector.inspect(binary)
    end

    test "is malformed when the scan starts before any frame header" do
      binary = jpeg([segment(0xE0, "JFIF\0"), segment(0xDA, <<1, 0, 0, 63, 0>>)])

      assert Inspector.inspect(binary) == {:error, :malformed}
    end

    test "is malformed when the file is truncated mid-frame" do
      full = jpeg([frame(0xC0, 1600, 2400, 3)])
      truncated = binary_part(full, 0, byte_size(full) - 10)

      assert Inspector.inspect(truncated) == {:error, :malformed}
    end

    test "is malformed when the frame segment is cut short of its declared length" do
      full = jpeg([frame(0xC0, 1600, 2400, 3)])
      truncated = binary_part(full, 0, byte_size(full) - 6)

      assert Inspector.inspect(truncated) == {:error, :malformed}
    end

    test "is malformed when a segment claims more length than the file holds" do
      binary = <<0xFF, 0xD8, 0xFF, 0xE0, 60_000::16, 0, 0, 0>>

      assert Inspector.inspect(binary) == {:error, :malformed}
    end

    test "is malformed when the frame header reports a zero dimension" do
      binary = jpeg([frame(0xC0, 1600, 0, 3)])

      assert Inspector.inspect(binary) == {:error, :malformed}
    end

    test "is malformed when nothing follows the start of image" do
      assert Inspector.inspect(<<0xFF, 0xD8>>) == {:error, :malformed}
    end
  end

  describe "inspect/1 on PNG" do
    defp png(width, height, color_type) do
      <<137, 80, 78, 71, 13, 10, 26, 10, 13::32>> <>
        "IHDR" <> <<width::32, height::32, 8, color_type, 0, 0, 0>>
    end

    test "reads dimensions from IHDR" do
      assert Inspector.inspect(png(1600, 2400, 2)) ==
               {:ok, %{format: :png, width: 1600, height: 2400, components: 3}}
    end

    test "maps each colour type to its channel count" do
      for {color_type, components} <- [{0, 1}, {2, 3}, {3, 1}, {4, 2}, {6, 4}] do
        assert {:ok, %{components: ^components}} = Inspector.inspect(png(800, 600, color_type))
      end
    end

    test "is malformed for an unknown colour type" do
      assert Inspector.inspect(png(800, 600, 5)) == {:error, :malformed}
    end

    test "is malformed when the signature is not followed by IHDR" do
      binary = <<137, 80, 78, 71, 13, 10, 26, 10, 13::32>> <> "IEND"

      assert Inspector.inspect(binary) == {:error, :malformed}
    end
  end

  describe "inspect/1 on anything else" do
    test "rejects a format it does not know" do
      assert Inspector.inspect("GIF89a" <> :binary.copy(<<0>>, 40)) ==
               {:error, :unsupported_format}
    end

    test "rejects plain text" do
      assert Inspector.inspect("this is not an image") == {:error, :unsupported_format}
    end

    test "rejects an empty binary" do
      assert Inspector.inspect("") == {:error, :unsupported_format}
    end
  end
end
