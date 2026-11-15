defmodule LumenViaeWeb.Live.Prayers.Novena do
  @moduledoc """
  A novena as its twin's page reads it, one day at a time: which day the
  link names (`?day=`), whether its days differ at all, and a day's parts
  as the blocks the page sets.

  A part is one of:

    * `%{type: :prayer}`: words with a heading, the day's own (its
      `title`) or a book prayer's, with how many times it is said and the
      book prayer that may be said in its place;
    * `%{type: :said}`: a run of the prayers everyone knows (the Our
      Father, the Hail Mary, the Glory Be, the Sign of the Cross), named
      in one direction line with a link to each, as the twin prints them
      (`[Our Father, Hail Mary, Glory Be.]`);
    * `%{type: :rosary}`: the decades of the Rosary prayed there, as a
      direction line.

  Presentation only, over a `LumenViaeWeb.Live.Prayers.Book` loaded with
  its novenas; the days and their parts are the domain's.
  """

  alias LumenViaeWeb.Live.Prayers.{Book, PrayerText}

  @said_ids ~w(sign_of_cross our_father hail_mary glory_be)

  @numbers ~w(one two three four five six seven eight nine ten eleven twelve thirteen
              fourteen fifteen sixteen seventeen eighteen nineteen twenty twenty-one
              twenty-two twenty-three twenty-four twenty-five twenty-six twenty-seven
              twenty-eight twenty-nine thirty)

  @ordinals ~w(first second third fourth fifth sixth seventh eighth ninth tenth)

  @doc """
  The day a `?day=` value names, counted from 1. Anything that is not one
  of the novena's days (missing, `0`, past the end, a word) is day 1.
  """
  def day_number(%{days: days}, value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n >= 1 and n <= length(days) -> n
      _other -> 1
    end
  end

  def day_number(_novena, _value), do: 1

  @doc "The day numbered `n`."
  def day(%{days: days}, n), do: Enum.at(days, n - 1)

  @doc """
  True when every day prays the same parts (the St Andrew Christmas
  novena: one prayer, fifteen times a day, for 25 days): the page then
  sets the one day, with no days to choose between.
  """
  def same_every_day?(%{days: [first | rest]}),
    do: Enum.all?(rest, &(&1.parts == first.parts))

  def same_every_day?(_novena), do: true

  @doc "The day's link: day 1 is the bare page, a default never written."
  def day_path(prayer_id, 1), do: Book.prayer_path(prayer_id)
  def day_path(prayer_id, n), do: Book.prayer_path(prayer_id) <> "?day=#{n}"

  @doc "The line under the title: how it is prayed, then the book's note on it."
  def intro(%{days: days, note: note} = novena) do
    count = number_word(length(days))

    lead =
      if same_every_day?(novena),
        do: "Pray it every day, for #{count} days.",
        else: "Pray one day at a time, for #{count} days in a row."

    Enum.join([lead, note] |> Enum.reject(&(&1 in [nil, ""])), " ")
  end

  @doc "The day's parts in order, as blocks; runs of the everyday prayers are one line."
  def blocks(%{parts: parts}, %Book{} = book) do
    parts
    |> Enum.map(&block(&1, book))
    |> Enum.reject(&is_nil/1)
    |> Enum.chunk_while(nil, &merge_said/2, &flush/1)
  end

  defp block(%{kind: "rosary", decades: [_ | _] = decades}, _book),
    do: %{type: :rosary, text: "Pray #{decades_phrase(decades)} of the Rosary."}

  defp block(%{prayer_id: id} = part, book) when is_binary(id) do
    case Book.prayer(book, id) do
      nil ->
        nil

      prayer when id in @said_ids ->
        %{type: :said, items: [%{prayer: prayer, times: part.times}]}

      prayer ->
        %{
          type: :prayer,
          heading: prayer.title,
          path: Book.prayer_path(id),
          times: part.times,
          instead: instead(part, book),
          stanzas: PrayerText.stanzas(prayer.english, nil, "english")
        }
    end
  end

  defp block(%{text: text} = part, book) when is_binary(text) and text != "" do
    %{
      type: :prayer,
      heading: part.title,
      path: nil,
      times: part.times,
      instead: instead(part, book),
      stanzas: PrayerText.stanzas(text, nil, "english")
    }
  end

  defp block(_part, _book), do: nil

  defp instead(%{or_prayer_id: id}, book) when is_binary(id), do: Book.prayer(book, id)
  defp instead(_part, _book), do: nil

  defp merge_said(%{type: :said} = block, %{type: :said} = held),
    do: {:cont, %{held | items: held.items ++ block.items}}

  defp merge_said(block, nil), do: {:cont, block}
  defp merge_said(block, held), do: {:cont, held, block}

  defp flush(nil), do: {:cont, nil}
  defp flush(held), do: {:cont, held, nil}

  @doc "\"twice\", \"nine times\": how often a part is said, or nil for once."
  def times_phrase(nil), do: nil
  def times_phrase(1), do: nil
  def times_phrase(2), do: "twice"
  def times_phrase(n), do: "#{number_word(n)} times"

  @doc "\"the first three decades\", \"the last two decades\", \"the third decade\"."
  def decades_phrase([1, 2, 3, 4, 5]), do: "the five decades"
  def decades_phrase([n]) when n in 1..10, do: "the #{Enum.at(@ordinals, n - 1)} decade"

  def decades_phrase([1 | _] = decades) do
    if consecutive?(decades),
      do: "the first #{number_word(length(decades))} decades",
      else: listed(decades)
  end

  def decades_phrase(decades) do
    if consecutive?(decades) and List.last(decades) == 5,
      do: "the last #{number_word(length(decades))} decades",
      else: listed(decades)
  end

  defp listed(decades), do: "decades #{Enum.join(decades, ", ")}"

  defp consecutive?(decades), do: decades == Enum.to_list(hd(decades)..List.last(decades))

  defp number_word(n) when n in 1..30, do: Enum.at(@numbers, n - 1)
  defp number_word(n), do: Integer.to_string(n)
end
