defmodule LumenViae.Rosary.Meditation.SetSpanishTest do
  @moduledoc """
  The meditation sets' own Spanish (`priv/meditations/es/sets.json`):
  pinned, one entry per visible set, and each field served only while the
  English it stands for is unchanged.
  """
  use ExUnit.Case, async: false

  alias LumenViae.Rosary.Meditation.SetSpanish

  # Change the file: bump its updated_at and set the new pair here. Each
  # set's sources are in priv/meditations/es/SOURCES.md.
  @pinned {~U[2026-11-05 03:30:00Z], "065f43fdddc1e8cb"}

  # The 23 sets production shows (5 November 2026), Sheen's three
  # included: the set's words are the team's, not his.
  @visible_sets [
    25,
    26,
    27,
    28,
    29,
    30,
    42,
    45,
    46,
    48,
    52,
    53,
    54,
    55,
    56,
    58,
    59,
    60,
    61,
    62,
    63,
    64,
    65
  ]

  test "the file is pinned by its date and words" do
    assert {SetSpanish.updated_at(), SetSpanish.file_version()} == @pinned, """
    priv/meditations/es/sets.json changed (now #{DateTime.to_iso8601(SetSpanish.updated_at())}, #{SetSpanish.file_version()}).
    Bump its updated_at and set @pinned to the new pair.
    """
  end

  test "every visible set has its Spanish" do
    assert SetSpanish.ids() == @visible_sets
  end

  test "a field is served while its English matches, and null once it changes" do
    english = %{
      name: "A Set",
      author: "An Author",
      description: "A description.",
      source: "A Book",
      artwork_alt: "Portrait"
    }

    entries = %{
      "7" => %{
        "description" => %{"es" => "Una descripción.", "english" => "x"},
        "image_alt" => %{"es" => "Retrato", "english" => SetSpanish.fingerprint("Portrait")}
      }
    }

    Application.put_env(:lumen_viae, SetSpanish, entries: entries)
    on_exit(fn -> Application.delete_env(:lumen_viae, SetSpanish) end)

    assert SetSpanish.translation(7, english) == %{
             name: nil,
             author: nil,
             description: nil,
             source: nil,
             artwork_alt: "Retrato",
             ai_translated: true
           }

    assert SetSpanish.translation(7, %{english | artwork_alt: "Changed"}) == nil
    assert SetSpanish.translation(8, english) == nil
  end

  test "an english of null is served while the English is still empty" do
    entries = %{"7" => %{"source" => %{"es" => "Mística Ciudad de Dios", "english" => nil}}}
    Application.put_env(:lumen_viae, SetSpanish, entries: entries)
    on_exit(fn -> Application.delete_env(:lumen_viae, SetSpanish) end)

    assert SetSpanish.translation(7, %{
             name: nil,
             author: nil,
             description: nil,
             source: nil,
             artwork_alt: nil
           }).source ==
             "Mística Ciudad de Dios"

    assert SetSpanish.translation(7, %{
             name: nil,
             author: nil,
             description: nil,
             source: "A Book",
             artwork_alt: nil
           }) ==
             nil
  end
end
