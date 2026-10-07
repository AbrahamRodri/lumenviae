defmodule LumenViaeWeb.Components.ArtworkPictureTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias LumenViaeWeb.Components.ArtworkPicture

  defp painting(widths) do
    %{
      image_key: "sets/27/8f21c4d9e0b3a7f6.jpg",
      image_width: 3051,
      image_height: 1667,
      image_variant_widths: widths
    }
  end

  defp picture(record) do
    render_component(&ArtworkPicture.artwork_picture/1,
      record: record,
      alt: "The Finding in the Temple",
      sizes: "(min-width: 640px) 96px, 80px",
      class: "w-full object-cover"
    )
  end

  defp parse(html), do: LazyHTML.from_fragment(html)

  test "with no recorded variants it is the plain original, never a picture" do
    html = picture(painting([]))
    doc = parse(html)

    assert LazyHTML.query(doc, "picture") |> Enum.count() == 0
    assert LazyHTML.query(doc, "source") |> Enum.count() == 0

    [src] = doc |> LazyHTML.query("img") |> LazyHTML.attribute("src")
    assert src =~ "sets/27/8f21c4d9e0b3a7f6.jpg"
  end

  test "offers the recorded variants as WebP, then the original at its width, and the original as the fallback" do
    doc = parse(picture(painting([960, 480])))

    [srcset] = doc |> LazyHTML.query("picture > source") |> LazyHTML.attribute("srcset")
    [type] = doc |> LazyHTML.query("picture > source") |> LazyHTML.attribute("type")
    [sizes] = doc |> LazyHTML.query("picture > source") |> LazyHTML.attribute("sizes")

    assert type == "image/webp"
    assert sizes == "(min-width: 640px) 96px, 80px"

    assert [
             [_, "480w"],
             [_, "960w"],
             [_, "3051w"]
           ] = srcset |> String.split(", ") |> Enum.map(&String.split(&1, " "))

    assert srcset =~ "sets/27/8f21c4d9e0b3a7f6-480.webp 480w"
    assert srcset =~ "sets/27/8f21c4d9e0b3a7f6-960.webp 960w"
    assert srcset =~ "sets/27/8f21c4d9e0b3a7f6.jpg 3051w"
    refute srcset =~ "1600"

    [src] = doc |> LazyHTML.query("picture > img") |> LazyHTML.attribute("src")
    assert src =~ "sets/27/8f21c4d9e0b3a7f6.jpg"
  end

  test "a partial backfill still offers the original, so a 2x screen is not left soft" do
    doc = parse(picture(painting([480])))
    [srcset] = doc |> LazyHTML.query("picture > source") |> LazyHTML.attribute("srcset")

    assert srcset =~ "-480.webp 480w"
    assert srcset =~ "sets/27/8f21c4d9e0b3a7f6.jpg 3051w"
  end

  test "reserves the painting's box and loads it lazily, either way" do
    for widths <- [[], [480]] do
      img = picture(painting(widths)) |> parse() |> LazyHTML.query("img")

      assert LazyHTML.attribute(img, "width") == ["3051"]
      assert LazyHTML.attribute(img, "height") == ["1667"]
      assert LazyHTML.attribute(img, "loading") == ["lazy"]
      assert LazyHTML.attribute(img, "decoding") == ["async"]
      assert LazyHTML.attribute(img, "alt") == ["The Finding in the Temple"]
    end
  end
end
