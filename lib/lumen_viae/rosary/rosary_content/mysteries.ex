defmodule LumenViae.Rosary.RosaryContent.Mysteries do
  @moduledoc """
  The `mysteries` section of `LumenViae.Rosary.RosaryContent`: the
  mysteries the app knows (`Categories.mystery_keys/0`), read from the
  `mysteries` table in the order they are prayed, each with the
  announcement `LumenViae.Rosary.PrayerAudio` records for it.

  The rows are the curators', so they also go into the document's
  `version` (`RosaryContent.Current`): `rows/1` is what both read. A row
  whose key the app does not know is not served.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Artwork
  alias LumenViae.Rosary.Artwork.Published
  alias LumenViae.Rosary.Categories
  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Mystery
  alias LumenViae.Rosary.PrayerAudio
  alias LumenViae.Rosary.RosaryContent.SpanishNames
  alias LumenViae.Rosary.Types

  # GraphQL selects only the fields a query names, so the language is
  # asked for here or it would arrive empty.
  @impl true
  def load(_query, _opts, _context), do: [:lang]

  @impl true
  def calculate(records, _opts, context) do
    opts = Ash.Context.to_opts(context)

    Enum.map(records, fn record ->
      opts |> rows(Content.language(record.lang)) |> Enum.map(&elem(&1, 0))
    end)
  end

  @doc """
  The served mysteries in prayer order, each as `{%Types.RosaryMystery{},
  updated_at}`, the second being the row's last change as a UTC
  `DateTime`.

  In `"es"` a mystery's `name` and `fruit` are `SpanishNames.mystery/1`'s
  where it has them; every other field, the announcement included, is the
  row's English.
  """
  @spec rows(keyword, String.t()) :: [{Types.RosaryMystery.t(), DateTime.t()}]
  def rows(opts, lang \\ "en") do
    announcements = Map.new(PrayerAudio.announcements(), &{&1.mystery, &1.text})
    positions = Categories.mystery_keys() |> Enum.with_index() |> Map.new()

    Mystery
    |> Ash.Query.for_read(:read, %{}, opts)
    |> Ash.Query.load(:key)
    |> Ash.read!()
    |> Enum.filter(&Map.has_key?(positions, &1.key))
    |> Enum.sort_by(&Map.fetch!(positions, &1.key))
    |> Enum.map(fn mystery ->
      {%Types.RosaryMystery{
         key: mystery.key,
         category: mystery.category,
         order: mystery.order,
         name: mystery.name,
         description: mystery.description,
         scripture_reference: mystery.scripture_reference,
         fruit: mystery.fruit,
         key_verse: mystery.key_verse,
         key_verse_reference: mystery.key_verse_reference,
         artwork: if(Artwork.publishable?(mystery), do: Published.shape(mystery)),
         announcement: Map.fetch!(announcements, mystery.key)
       }
       |> in_language(lang), DateTime.from_naive!(mystery.updated_at, "Etc/UTC")}
    end)
  end

  defp in_language(%Types.RosaryMystery{key: key} = mystery, "es") do
    case SpanishNames.mystery(key) do
      nil -> mystery
      spanish -> %{mystery | name: spanish.name, fruit: spanish.fruit}
    end
  end

  defp in_language(mystery, _lang), do: mystery
end
