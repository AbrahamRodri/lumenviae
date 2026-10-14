defmodule LumenViaeWeb.Components.MysteryPaintingTest do
  @moduledoc """
  The app's paintings as the website serves them: one for every mystery
  and every category's card, each with its files on disk and a credit.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Categories
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

  test "a key with no painting is nil" do
    assert MysteryPainting.for_mystery("joyful_9") == nil
    assert MysteryPainting.for_category("cheerful") == nil
  end
end
