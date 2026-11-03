defmodule LumenViae.Rosary.RosaryContent.Prayers do
  @moduledoc """
  The `prayers` section of `LumenViae.Rosary.RosaryContent`:
  `LumenViae.Rosary.Content`'s prayers, in the order they are said, shaped
  as `LumenViae.Rosary.Types.RosaryPrayer`, in the language the read asked
  for.

  A title and a text are plain maps, not their typed structs: the JSON:API
  serializer writes only the keys a map holds, so an English document
  carries `en` and `la` and no `es` at all, exactly as before Spanish was
  served, and a Spanish one carries all three.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Content

  # GraphQL selects only the fields a query names, so the language is
  # asked for here or it would arrive empty.
  @impl true
  def load(_query, _opts, _context), do: [:lang]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      record.lang |> Content.prayers() |> Enum.map(&shape/1)
    end)
  end

  # A plain map too, for the same reason: `ai_translated` is there only
  # when it is true, so every other prayer reads as it always has.
  defp shape(%{"id" => id, "group" => group, "title" => title, "text" => text} = prayer) do
    shaped = %{id: id, group: group, title: languages(title), text: languages(text)}

    if prayer["ai_translated"] == true, do: Map.put(shaped, :ai_translated, true), else: shaped
  end

  # Only the languages served, so a stray key in a content file never
  # reaches a document.
  defp languages(value) do
    value
    |> Map.take(["en", "la", "es"])
    |> Map.new(fn {lang, words} -> {String.to_existing_atom(lang), words} end)
  end
end
