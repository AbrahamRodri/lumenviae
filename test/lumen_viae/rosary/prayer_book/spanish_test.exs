defmodule LumenViae.Rosary.PrayerBook.SpanishTest do
  @moduledoc """
  The Prayer Book's Spanish (`priv/library/es/prayer_book.json` and the
  Rosary's Spanish the book reuses): pinned, in the book's order, and never
  a second copy of a Rosary prayer.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.PrayerBook.Spanish

  # Change the file: bump its updated_at and set the new pair here. Every
  # text must come from an official source listed in
  # priv/library/es/SOURCES.md.
  @pinned {~U[2026-11-03 03:10:00Z], "4ed9a06f10df3ea9"}

  @file_ids ~w(act_of_faith act_of_hope act_of_charity regina_caeli anima_christi sub_tuum
               jesus_i_trust_in_thee my_lord_and_my_god pardon_prayer miraculous_medal
               spiritual_communion angels_prayer_fatima reparation_sacred_heart ad_te_beate_ioseph
               nada_te_turbe nicene_creed benedictus angele_dei angelus veni_creator
               veni_sancte_spiritus magnificat te_deum jesus_prayer peace_prayer
               litany_sacred_heart)

  test "the file is pinned by its date and words" do
    assert {Spanish.file_updated_at(), Spanish.file_version()} == @pinned, """
    priv/library/es/prayer_book.json changed (now #{DateTime.to_iso8601(Spanish.file_updated_at())}, #{Spanish.file_version()}).
    Bump its updated_at and set @pinned to the new pair.
    """
  end

  test "every translation is a prayer the book prints, in the book's order" do
    book_ids = Enum.map(Library.served(:prayer_book, "prayers"), & &1.id)
    ids = Enum.map(Spanish.prayers(), & &1.id)

    assert ids == Enum.filter(book_ids, &(&1 in ids))
    assert Enum.sort(@file_ids) == Enum.sort(ids -- Content.prayer_ids())
  end

  test "each one has a title and words, and only the keys a client reads" do
    for prayer <- Spanish.prayers() do
      assert is_binary(prayer.title) and prayer.title != "", prayer.id
      assert is_binary(prayer.text) and prayer.text != "", prayer.id
      assert Enum.sort(Map.keys(prayer) -- [:ai_translated]) == [:id, :text, :title]
      assert Map.get(prayer, :ai_translated, true) == true
    end
  end

  test "a Rosary prayer the book prints is the Rosary's own Spanish" do
    rosary = Map.new(Content.prayers("es"), &{&1["id"], &1})
    book_ids = Enum.map(Library.served(:prayer_book, "prayers"), & &1.id)
    reused = for p <- Spanish.prayers(), p.id in Content.prayer_ids(), do: p

    assert reused != []

    for prayer <- reused do
      assert prayer.id in book_ids
      assert prayer.title == rosary[prayer.id]["title"]["es"]
      assert prayer.text == Enum.join(rosary[prayer.id]["text"]["es"], "\n")
    end

    # A Rosary prayer still in English (no official Spanish) is left out.
    for {id, prayer} <- rosary, prayer["text"]["es"] == prayer["text"]["en"] do
      refute id in Enum.map(reused, & &1.id)
    end
  end

  test "the Spanish date is never earlier than either source" do
    refute DateTime.compare(Spanish.updated_at(), Spanish.file_updated_at()) == :lt
    refute DateTime.compare(Spanish.updated_at(), Content.updated_at("es")) == :lt
  end
end
