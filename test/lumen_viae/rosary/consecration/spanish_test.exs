defmodule LumenViae.Rosary.Consecration.SpanishTest do
  @moduledoc """
  The Consecration's Spanish (`priv/library/es/consecration.json` and the
  Prayer Book's Spanish it reuses): pinned, keyed and ordered as the
  English, and never a second copy of a Prayer Book prayer.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Consecration.Spanish
  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.PrayerBook

  # Change the file: bump its updated_at and set the new pair here. Every
  # reading's source, or its marking as the team's translation, is listed
  # in priv/library/es/SOURCES.md.
  @pinned {~U[2026-11-03 16:38:00Z], "83e446a66cf2d90b"}

  defp english(section), do: Library.served(:consecration, section)

  test "the file is pinned by its date and words" do
    assert {Spanish.file_updated_at(), Spanish.file_version()} == @pinned, """
    priv/library/es/consecration.json changed (now #{DateTime.to_iso8601(Spanish.file_updated_at())}, #{Spanish.file_version()}).
    Bump its updated_at and set @pinned to the new pair.
    """
  end

  test "every phase, day, prayer and feast has Spanish, in the English order" do
    spanish = Spanish.translation()

    assert Enum.map(spanish.phases, & &1.id) == Enum.map(english("phases"), & &1.id)
    assert Enum.map(spanish.days, & &1.number) == Enum.map(english("days"), & &1.number)
    assert Enum.map(spanish.prayers, & &1.id) == Enum.map(english("prayers"), & &1.id)
    assert Enum.map(spanish.feasts, & &1.id) == Enum.map(english("feasts"), & &1.id)
  end

  test "every reading has Spanish, and only the gap-filled ones are marked" do
    readings =
      for day <- Spanish.translation().days, reading <- day.readings, do: {day.number, reading}

    assert length(readings) == english("days") |> Enum.flat_map(& &1.readings) |> length()

    # Day 33's second reading fills a passage the 1885 Spanish edition leaves out.
    assert for({number, %{ai_translated: true} = r} <- readings, do: {number, r.order}) == [
             {33, 2}
           ]
  end

  test "each day's readings are its own, in order" do
    days = Map.new(english("days"), &{&1.number, Enum.map(&1.readings, fn r -> r.order end)})

    for day <- Spanish.translation().days do
      orders = Enum.map(day.readings, & &1.order)
      assert orders == Enum.filter(days[day.number], &(&1 in orders)), "day #{day.number}"
    end
  end

  test "every part has words, and only the keys a client reads" do
    spanish = Spanish.translation()

    check = fn entry, keys ->
      for key <- keys,
          do: assert(is_binary(entry[key]) and entry[key] != "", inspect({entry, key}))

      assert Map.get(entry, :ai_translated, true) == true
      Enum.sort(Map.keys(entry) -- [:ai_translated])
    end

    for phase <- spanish.phases,
        do: assert(check.(phase, [:name, :subtitle]) == [:id, :name, :subtitle])

    for feast <- spanish.feasts,
        do: assert(check.(feast, [:name, :description]) == [:description, :id, :name])

    for prayer <- spanish.prayers,
        do: assert(check.(prayer, [:title, :text]) == [:id, :text, :title])

    for day <- spanish.days do
      assert check.(day, [:title, :journal_prompt]) == [
               :journal_prompt,
               :number,
               :readings,
               :title
             ]

      for reading <- day.readings do
        assert check.(reading, [:title, :text, :source]) == [:order, :source, :text, :title]
      end
    end
  end

  test "the titles, questions, phases and feasts are the team's translation, marked" do
    spanish = Spanish.translation()

    for part <- spanish.phases ++ spanish.feasts ++ spanish.days do
      assert part[:ai_translated] == true, inspect(part)
    end
  end

  test "a prayer the Prayer Book prints is the Prayer Book's own Spanish" do
    book = Map.new(PrayerBook.Spanish.prayers(), &{&1.id, &1})

    reused =
      for prayer <- Spanish.translation().prayers, Map.has_key?(book, prayer.id), do: prayer

    assert length(reused) == 8

    for prayer <- reused, do: assert(prayer == book[prayer.id])
  end

  test "the Spanish date is never earlier than either source" do
    refute DateTime.compare(Spanish.updated_at(), Spanish.file_updated_at()) == :lt
    refute DateTime.compare(Spanish.updated_at(), PrayerBook.Spanish.updated_at()) == :lt
  end
end
