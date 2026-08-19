defmodule LumenViae.Curation.ArtworkUploadTest do
  @moduledoc """
  Every case here is either pure validation or key derivation, so nothing in
  this file reaches S3. The successful `upload/3` path is deliberately not
  exercised: it is one `S3.upload_public/2` call past `prepare/3`, and a
  test that could put an object in a real bucket depending on which
  environment variables happen to be set is worse than no test.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Curation.ArtworkUpload

  defp jpeg(width, height, components \\ 3) do
    frame =
      <<8, height::16, width::16, components::8>> <> :binary.copy(<<1, 0x11, 0>>, components)

    <<0xFF, 0xD8, 0xFF, 0xC0, byte_size(frame) + 2::16>> <> frame
  end

  defp png(width, height) do
    <<137, 80, 78, 71, 13, 10, 26, 10, 13::32>> <>
      "IHDR" <> <<width::32, height::32, 8, 2, 0, 0, 0>>
  end

  describe "prepare/3" do
    test "names the object after its own bytes, under the scope and id" do
      binary = jpeg(1600, 2400)

      assert {:ok, %{key: key}} = ArtworkUpload.prepare(binary, :set, 27)

      expected =
        :sha256
        |> :crypto.hash(binary)
        |> Base.encode16(case: :lower)
        |> binary_part(0, 16)

      assert key == "sets/27/#{expected}.jpg"
    end

    test "files meditation artwork under its own prefix" do
      assert {:ok, %{key: key}} = ArtworkUpload.prepare(jpeg(1600, 2400), :meditation, 412)

      assert key =~ ~r"^meditations/412/[0-9a-f]{16}\.jpg$"
    end

    test "the same painting on the same set always lands on the same key" do
      binary = jpeg(1600, 2400)

      assert {:ok, %{key: first}} = ArtworkUpload.prepare(binary, :set, 27)
      assert {:ok, %{key: second}} = ArtworkUpload.prepare(binary, :set, 27)

      assert first == second
    end

    # This is the whole cache-invalidation story: a replacement painting gets
    # a new URL, so no cache anywhere has to be told about it.
    test "a different painting on the same set lands on a different key" do
      assert {:ok, %{key: first}} = ArtworkUpload.prepare(jpeg(1600, 2400), :set, 27)
      assert {:ok, %{key: second}} = ArtworkUpload.prepare(jpeg(1600, 2401), :set, 27)

      refute first == second
    end

    test "returns the dimensions the header reported" do
      assert {:ok, %{info: info}} = ArtworkUpload.prepare(jpeg(1600, 2400), :set, 27)

      assert info == %{format: :jpeg, width: 1600, height: 2400, components: 3}
    end

    test "accepts a landscape painting" do
      assert {:ok, _} = ArtworkUpload.prepare(jpeg(2400, 1600), :set, 27)
    end

    test "accepts the exact boundary sizes" do
      assert {:ok, _} = ArtworkUpload.prepare(jpeg(1200, 4000), :set, 27)
    end
  end

  describe "prepare/3 rejections" do
    test "refuses a file over 12 MB before it parses anything" do
      oversized = :binary.copy(<<0>>, 12 * 1024 * 1024 + 1)

      assert {:error, message} = ArtworkUpload.prepare(oversized, :set, 27)
      assert message =~ "12.0 MB"
      assert message =~ "The limit is 12 MB"
    end

    test "refuses a PNG, naming the format" do
      assert {:error, message} = ArtworkUpload.prepare(png(1600, 2400), :set, 27)
      assert message =~ "PNG"
      assert message =~ "JPEG"
    end

    test "refuses something that is not an image at all" do
      assert {:error, message} = ArtworkUpload.prepare("not an image", :set, 27)
      assert message =~ "not a JPEG"
    end

    test "refuses a truncated JPEG" do
      full = jpeg(1600, 2400)
      truncated = binary_part(full, 0, byte_size(full) - 6)

      assert {:error, message} = ArtworkUpload.prepare(truncated, :set, 27)
      assert message =~ "truncated"
    end

    test "refuses a CMYK JPEG" do
      assert {:error, message} = ArtworkUpload.prepare(jpeg(1600, 2400, 4), :set, 27)
      assert message =~ "CMYK"
    end

    test "refuses a painting whose shortest side is under 1200px" do
      assert {:error, message} = ArtworkUpload.prepare(jpeg(900, 2400), :set, 27)
      assert message =~ "shortest side is 900px"
      assert message =~ "1200px"
    end

    test "refuses a painting whose longest side is over 4000px" do
      assert {:error, message} = ArtworkUpload.prepare(jpeg(1600, 5000), :set, 27)
      assert message =~ "longest side is 5000px"
      assert message =~ "4000px"
    end
  end

  describe "upload/3" do
    test "applies the same rules on the real entry point, before any S3 call" do
      assert {:error, message} = ArtworkUpload.upload(png(1600, 2400), :set, 27)

      assert message =~ "PNG"
    end
  end

  describe "rules/0" do
    test "states every limit the admin form has to explain" do
      rules = ArtworkUpload.rules()

      assert rules =~ "JPEG"
      assert rules =~ "12 MB"
      assert rules =~ "1200px"
      assert rules =~ "4000px"
      assert rules =~ "CMYK"
    end
  end
end
