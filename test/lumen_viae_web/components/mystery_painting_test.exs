defmodule LumenViaeWeb.Components.MysteryPaintingTest do
  @moduledoc """
  The app's paintings as the website serves them: one for every mystery
  and every category's card, each with its files on disk and a credit.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Categories
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias LumenViaeWeb.Components.MysteryPainting

  @static Path.expand("../../../priv/static", __DIR__)

  test "every mystery of every category has a painting" do
    for slug <- Categories.slugs(), order <- 1..Categories.mystery_count(slug) do
      assert MysteryPainting.for_mystery("#{slug}_#{order}"), "no painting for #{slug}_#{order}"
    end
  end

  test "every category's card has a painting, the Seven Sorrows' its Pieta" do
    for slug <- Categories.slugs(), do: assert(MysteryPainting.for_category(slug))

    assert MysteryPainting.for_category("seven_sorrows").name == "seven_sorrows_pieta"
    assert MysteryPainting.for_category("joyful") == MysteryPainting.for_mystery("joyful_1")
  end

  test "each painting's files are on disk, and it says what it is" do
    for slug <- Categories.slugs(), order <- 1..Categories.mystery_count(slug) do
      painting = MysteryPainting.for_mystery("#{slug}_#{order}")

      files =
        [painting.src | painting.srcset |> String.split(", ") |> Enum.map(&hd(String.split(&1)))]

      for file <- files, do: assert(File.exists?(Path.join(@static, file)), "missing #{file}")
      assert painting.title && painting.artist, "no credit for #{painting.name}"
      assert painting.alt =~ painting.title
    end
  end

  test "every painting offers its 240 pixel thumbnail first, for the small arches" do
    names =
      Path.join(@static, "images/paintings/manifest.json")
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("paintings")
      |> Enum.map(& &1["name"])

    for name <- names do
      painting = MysteryPainting.for_name(name)
      [first | _] = String.split(painting.srcset, ", ")
      [file, width] = String.split(first)

      assert file == "/images/paintings/#{name}-240.webp"
      assert String.to_integer(String.trim_trailing(width, "w")) <= 240
      assert File.exists?(Path.join(@static, file)), "missing #{file}"
    end
  end

  test "the painting a page opens on is fetched first; the rest wait their turn" do
    hero =
      render_component(&MysteryPainting.picture/1,
        key: "joyful_1",
        sizes: "100vw",
        loading: "eager",
        fetchpriority: "high"
      )

    assert hero =~ ~s(loading="eager")
    assert hero =~ ~s(fetchpriority="high")

    thumb =
      render_component(&MysteryPainting.picture/1,
        key: "joyful_1",
        sizes: "56px"
      )

    assert thumb =~ ~s(loading="lazy")
    refute thumb =~ "fetchpriority"

    eager_book_painting =
      render_component(&LumenViaeWeb.Live.Prayers.Painting.painting/1,
        painting: {"joyful_annunciation", 0.5, 0.3},
        sizes: "100vw",
        loading: "eager"
      )

    assert eager_book_painting =~ ~s(fetchpriority="high")
  end

  test "a key with no painting is nil" do
    assert MysteryPainting.for_mystery("joyful_9") == nil
    assert MysteryPainting.for_category("cheerful") == nil
  end
end
