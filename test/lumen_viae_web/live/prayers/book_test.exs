defmodule LumenViaeWeb.Live.Prayers.BookTest do
  @moduledoc """
  The Prayer Book as the Prayers pages read it: the search ranked as the
  app ranks it, the topics a search names, a prayer's home chapter and
  the season's song to Mary.
  """
  use ExUnit.Case, async: true

  alias LumenViaeWeb.Live.Prayers.Book

  setup_all do
    %{book: Book.load(nil)}
  end

  defp ids(prayers), do: Enum.map(prayers, & &1.id)

  test "a name answers when every word searched begins one of its words", %{book: book} do
    assert "hail_mary" in ids(Book.search(book, "hail ma"))
    assert hd(ids(Book.search(book, "memorare"))) == "memorare"
  end

  test "st and saint are one word in a name", %{book: book} do
    saint = ids(Book.search(book, "saint joseph"))
    st = ids(Book.search(book, "st joseph"))

    assert saint != []
    # The names answer alike; "st joseph" also finds the prayers whose
    # words hold it, after them.
    assert Enum.take(st, length(saint)) == saint
  end

  test "accents and ligatures fold, and coel reads as cael", %{book: book} do
    assert "regina_caeli" in ids(Book.search(book, "regina coeli"))
    assert "regina_caeli" in ids(Book.search(book, "Regina Cæli"))
  end

  test "the words of a prayer answer after the names", %{book: book} do
    hits = ids(Book.search(book, "fruit of thy womb"))
    assert "hail_mary" in hits
  end

  test "nothing to search finds nothing", %{book: book} do
    assert Book.search(book, "  ") == []
    assert Book.search(book, "zzqxv") == []
  end

  test "topics answer the words of their names, not \"prayer\"", %{book: book} do
    assert "our_lady" in Enum.map(Book.topics(book, "mary"), & &1.id)
    assert Book.topics(book, "prayers") == []
  end

  test "a prayer's home is the first chapter that lists it", %{book: book} do
    assert Book.home_chapter(book, "our_father").id == "first"
  end

  test "the season's song to Mary comes first on her shelf", %{book: book} do
    [first | rest] = Book.marian_shelf(book, ~D[2026-04-10])

    assert first.prayer.id == "regina_caeli"
    assert first.seasonal?
    assert "memorare" in Enum.map(rest, & &1.prayer.id)
    refute "hail_mary" in Enum.map(rest, & &1.prayer.id)
  end

  test "a prayer's Latin name shows only where the app knows it by it", %{book: book} do
    assert Book.second_title(Book.prayer(book, "our_father")) == "Pater Noster"
    assert Book.second_title(Book.prayer(book, "memorare")) =~ "Remember"
    assert Book.second_title(Book.prayer(book, "act_of_faith")) == nil
    assert Book.second_title(Book.prayer(book, "magnificat")) == "Magnificat"
  end

  test "a prayer the app homes elsewhere is headed by that topic", %{book: book} do
    assert Book.home_chapter(book, "hail_holy_queen").id == "our_lady"
    assert Book.home_chapter(book, "te_deum").id == "thanks"
  end

  test "the five parts hold every topic once, in the book's order", %{book: book} do
    parts = Book.parts(book)

    assert length(parts) == 5

    assert parts |> Enum.flat_map(& &1.chapters) |> Enum.sort_by(& &1.id) ==
             Enum.sort_by(book.chapters, & &1.id)

    assert hd(parts).chapters |> Enum.map(& &1.id) == ~w(first day short)
  end

  test "every painting the pages hang is one the website has", %{book: book} do
    alias LumenViaeWeb.Components.MysteryPainting

    paintings =
      Enum.map(book.chapters, &Book.topic_painting(&1.id)) ++
        Enum.map(Map.keys(book.prayers), &Book.prayer_painting(book, &1)) ++
        Enum.map(~w(advent_eve february_2 easter pentecost_saturday), &Book.antiphon_painting/1) ++
        Map.values(Book.stand_ins())

    for {name, _x, _y} <- paintings do
      assert MysteryPainting.for_name(name), "no painting named #{name}"
    end
  end
end
