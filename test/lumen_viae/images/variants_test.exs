defmodule LumenViae.Images.VariantsTest do
  use ExUnit.Case, async: true

  alias LumenViae.Images.Variants
  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  doctest Variants

  # A real JPEG, so the test runs the decoder the uploads do: a gradient
  # rather than a flat colour, so the encoder has detail to keep.
  defp jpeg(width, height) do
    {:ok, x} = Operation.xyz(width, height)
    {:ok, gradient} = Operation.extract_band(x, 0)
    {:ok, gradient} = Operation.cast(gradient, :VIPS_FORMAT_UCHAR)
    {:ok, rgb} = Operation.bandjoin([gradient, gradient, gradient])
    {:ok, rgb} = Operation.copy(rgb, interpretation: :VIPS_INTERPRETATION_sRGB)
    {:ok, binary} = Operation.jpegsave_buffer(rgb, Q: 90)
    binary
  end

  defp decode(webp) do
    {:ok, image} = Image.new_from_buffer(webp)
    {Image.width(image), Image.height(image)}
  end

  describe "widths_for/1" do
    test "offers every width narrower than the original" do
      assert Variants.widths_for(4000) == [480, 960, 1600]
      assert Variants.widths_for(1601) == [480, 960, 1600]
    end

    test "never upscales, and never makes a variant the original's own width" do
      assert Variants.widths_for(1600) == [480, 960]
      assert Variants.widths_for(960) == [480]
      assert Variants.widths_for(480) == []
    end
  end

  describe "generate/1" do
    test "makes WebP at each width narrower than the original, keeping the aspect ratio" do
      assert {:ok, variants} = Variants.generate(jpeg(1700, 1200))

      assert Enum.map(variants, &elem(&1, 0)) == [480, 960, 1600]

      for {width, webp} <- variants do
        assert <<"RIFF", _size::32, "WEBP", _rest::binary>> = webp
        {w, h} = decode(webp)
        assert w == width
        assert_in_delta h, width * 1200 / 1700, 1
      end
    end

    test "skips the widths an original is too small for" do
      assert {:ok, variants} = Variants.generate(jpeg(1200, 1500))
      assert Enum.map(variants, &elem(&1, 0)) == [480, 960]
    end

    test "every variant is far smaller than the original" do
      original = jpeg(1700, 1200)
      assert {:ok, variants} = Variants.generate(original)

      for {_width, webp} <- variants, do: assert(byte_size(webp) < byte_size(original))
    end

    test "refuses bytes that are not an image" do
      assert {:error, _reason} = Variants.generate("not an image")
    end
  end
end
