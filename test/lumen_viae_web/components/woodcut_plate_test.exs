defmodule LumenViaeWeb.Components.WoodcutPlateTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias LumenViaeWeb.Components.WoodcutPlate
  alias LumenViaeWeb.Components.WoodcutPlate.Manifest

  @fixture_dir Path.expand("../../support/fixtures/woodcuts", __DIR__)
  @real_dir Path.expand("../../../priv/static/images/woodcuts", __DIR__)

  defp fixture_plates, do: Manifest.load(@fixture_dir, "/images/woodcuts")

  defp render_figure(plate, opts \\ []) do
    assigns = Map.merge(%{plate: plate, caption: true, variant: :light, size: :md}, Map.new(opts))

    rendered_to_string(~H"""
    <WoodcutPlate.plate_figure plate={@plate} caption={@caption} variant={@variant} size={@size} />
    """)
  end

  describe "Manifest.index/3" do
    test "indexes plates by mystery key with their URL and dimensions" do
      plates = fixture_plates()

      assert %{src: "/images/woodcuts/annunciation-durer.jpg", width: 800, height: 1121} =
               plates["joyful_1"]

      assert plates["joyful_1"].sources == []
    end

    test "offers AVIF and WebP copies only where the files exist, widest last" do
      assert [avif, webp] = fixture_plates()["luminous_1"].sources

      assert avif == %{type: "image/avif", srcset: "/images/woodcuts/baptism-dore.avif 800w"}

      assert webp == %{
               type: "image/webp",
               srcset:
                 "/images/woodcuts/baptism-dore-400.webp 400w, /images/woodcuts/baptism-dore.webp 800w"
             }
    end

    test "drops a plate whose image is missing" do
      manifest = %{"plates" => [%{"file" => "missing.jpg", "key" => "joyful_2"}]}
      assert Manifest.index(manifest, ["other.jpg"], "/x") == %{}
    end
  end

  describe "plate_figure/1" do
    test "renders the plate with its alt, size, lazy loading and caption" do
      html = render_figure(fixture_plates()["joyful_1"])

      assert html =~ ~s(<figure class="woodcut-plate woodcut-plate--md woodcut-plate--light")
      assert html =~ ~s(src="/images/woodcuts/annunciation-durer.jpg")
      assert html =~ ~s(alt="The angel Gabriel greets the Virgin Mary)
      assert html =~ ~s(width="800")
      assert html =~ ~s(height="1121")
      assert html =~ ~s(loading="lazy")
      assert html =~ ~s(decoding="async")
      refute html =~ "<picture"

      assert html =~ "<figcaption"
      assert html =~ "The Annunciation"
      assert html =~ "Albrecht Durer"
      assert html =~ "c. 1503"
      assert html =~ "Life of the Virgin"
      assert html =~ ~s(href="https://commons.wikimedia.org/wiki/File:Durer_annunciation.jpg")
    end

    test "wraps the image in a picture when other formats exist" do
      html = render_figure(fixture_plates()["luminous_1"], size: :lg)

      assert html =~ "<picture>"
      assert html =~ ~s(type="image/avif")
      assert html =~ ~s(type="image/webp")
      assert html =~ ~s|sizes="(min-width: 1024px) 28rem, 90vw"|
      assert html =~ ~s(src="/images/woodcuts/baptism-dore.jpg")
    end

    test "caption={false} leaves out the figcaption" do
      html = render_figure(fixture_plates()["joyful_1"], caption: false)

      assert html =~ "<img"
      refute html =~ "<figcaption"
      refute html =~ "commons.wikimedia.org"
    end

    test "the navy variant mounts the plate without inverting it" do
      html = render_figure(fixture_plates()["joyful_1"], variant: :navy)

      assert html =~ "woodcut-plate--navy"
      refute html =~ "invert"
    end
  end

  describe "woodcut_plate/1" do
    test "renders nothing for a key with no plate" do
      assigns = %{}

      assert rendered_to_string(~H"""
             <WoodcutPlate.woodcut_plate key="no_such_mystery" />
             """) == ""

      assert WoodcutPlate.plate("no_such_mystery") == nil
    end

    test "renders every plate in the manifest, and the manifest names only images on disk" do
      path = Path.join(@real_dir, "manifest.json")
      entries = if File.exists?(path), do: Jason.decode!(File.read!(path))["plates"], else: []

      assert entries |> Enum.map(& &1["key"]) |> Enum.sort() == WoodcutPlate.keys()

      for entry <- entries do
        assert File.exists?(Path.join(@real_dir, entry["file"])), "missing #{entry["file"]}"
        assert is_integer(entry["width"]) and is_integer(entry["height"])
        assert entry["alt"] not in [nil, ""]

        assigns = %{key: entry["key"]}

        html =
          rendered_to_string(~H"""
          <WoodcutPlate.woodcut_plate key={@key} variant={:navy} />
          """)

        assert html =~ ~s(src="/images/woodcuts/#{entry["file"]}")
        assert html =~ "woodcut-plate--navy"
      end
    end
  end
end
