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
  # text's source, or its marking as the team's translation, is listed in
  # priv/library/es/SOURCES.md.
  @pinned {~U[2026-11-14 16:00:00Z], "91aaf5d7dc21a023"}

  # The team's own translations, marked for the app's notice
  # (priv/library/es/SOURCES.md, the third list), plus the Seven Sorrows
  # closing prayer the Rosary marks, and St. Bridget's (its rubrics are the
  # team's; its verses Torres Amat's). The St Andrew and Sacred Heart
  # (efficacious) novenas left it on 14 Nov 2026 (orch-lead): St Andrew is
  # the Archdiocese of Philadelphia's Spanish, the Sacred Heart
  # sanpiodapietrelcina.org's.
  @ai_translated_count 85

  # A prayer newly added in English, until the Spanish team adds it to
  # priv/library/es/prayer_book.json.
  @awaiting_spanish ~w(holy_spirit_novena st_joseph_novena)

  # Abraham, 10 Nov 2026: "Follow how other apps do it". The prayer is
  # "Ave María", and counted "Ave Marías", never "Avemaría".
  test "the Hail Mary is written Ave María, and counted Ave Marías" do
    for prayer <- Spanish.prayers(), field <- [prayer.title, prayer.text] do
      for text <- List.wrap(field), is_binary(text) do
        refute text =~ ~r/avemar/i, "#{prayer.id}: #{text}"
      end
    end
  end

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
    # Every prayer the book prints has Spanish, but the ones still waiting
    # for it, which read in English until the Spanish team adds them.
    assert ids == book_ids -- @awaiting_spanish
    assert Enum.all?(@awaiting_spanish, &(&1 in book_ids))
  end

  test "the team's translations are marked" do
    assert Enum.count(Spanish.prayers(), &Map.get(&1, :ai_translated)) == @ai_translated_count
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

  # novenas-es: La Virgen Desatanudos, in Ascension Press's own Spanish
  # (not ai_translated), with the names ios-review settled.
  test "the Undoer of Knots novena has its Spanish, every part of its own words" do
    assert [knots | _] = Spanish.novenas()
    assert knots.id == "undoer_of_knots"
    assert knots.title == "La Virgen Desatanudos"
    assert knots.list_title == "Virgen Desatanudos"
    assert length(knots.day_titles) == 9

    [novena | _] = Library.served(:prayer_book, "novenas")
    own = for day <- novena.days, part <- day.parts, is_binary(part.id), uniq: true, do: part.id
    assert Enum.map(knots.parts, & &1.id) == own
    refute knots.ai_translated
    refute Enum.any?(knots.parts, & &1.ai_translated)

    twin = Enum.find(Spanish.prayers(), &(&1.id == "undoer_of_knots_novena"))
    assert twin.title == "Novena a la Virgen Desatanudos"
    refute Map.has_key?(twin, :ai_translated)
    assert Enum.all?(knots.parts, &String.contains?(twin.text, &1.text))

    assert Enum.find(knots.parts, &(&1.id == "undoer_of_knots_invocation")).text ==
             "María, Desatanudos, ruega por mí."
  end

  # novenas-api-nine (orch-lead, 14 Nov 2026): each novena's Spanish is a
  # published text, and each part stands in its twin. The one exception is
  # the Immaculate Conception's versicles and collects, the team's Spanish
  # from the Latin (Abraham, 10 Nov 2026, Q1 "A"), marked ai_translated.
  test "the new novenas' Spanish: published texts, by part, in their twins" do
    by_id = Map.new(Spanish.novenas(), &{&1.id, &1})

    assert Map.keys(by_id) |> Enum.sort() ==
             ~w(immaculate_conception our_lady_of_guadalupe our_mother_of_perpetual_help sacred_heart st_andrew_christmas undoer_of_knots)

    refute Map.has_key?(by_id, "holy_spirit")
    refute Map.has_key?(by_id, "st_joseph")

    novenas = Map.new(Library.served(:prayer_book, "novenas"), &{&1.id, &1})
    twins = Map.new(Spanish.prayers(), &{&1.id, &1})

    team_parts = ~w(immaculate_conception_tota_pulchra immaculate_conception_closing)

    for {id, spanish} <- by_id do
      refute spanish.ai_translated, id

      assert Enum.filter(spanish.parts, & &1.ai_translated) |> Enum.map(& &1.id) ==
               Enum.filter(Enum.map(spanish.parts, & &1.id), &(&1 in team_parts)),
             id

      assert length(spanish.day_titles) == novenas[id].length, id

      twin = twins[novenas[id].prayer_id]
      assert Enum.all?(spanish.parts, &String.contains?(twin.text, &1.text)), id
    end

    assert length(by_id["st_andrew_christmas"].day_titles) == 25

    [andrew] = by_id["st_andrew_christmas"].parts
    assert andrew.text =~ "dígnate, te suplico, oh Dios mío"
    refute Map.has_key?(twins["st_andrew_novena"], :ai_translated)

    ic = Map.new(by_id["immaculate_conception"].parts, &{&1.id, &1.text})
    assert ic["immaculate_conception_tota_pulchra"] =~ "℣. Toda hermosa eres, oh María."

    assert ic["immaculate_conception_closing"] =~
             "Oh Dios, que por la Inmaculada Concepción de la Virgen"

    assert ic["immaculate_conception_d1"] =~ "Aquí me tenéis a vuestros santísimos pies"
  end
end
