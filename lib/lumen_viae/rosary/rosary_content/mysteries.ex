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
  alias LumenViae.Rosary.Mystery
  alias LumenViae.Rosary.PrayerAudio
  alias LumenViae.Rosary.Types

  @impl true
  def calculate(records, _opts, context) do
    mysteries = context |> Ash.Context.to_opts() |> rows() |> Enum.map(&elem(&1, 0))

    Enum.map(records, fn _record -> mysteries end)
  end

  @doc """
  The served mysteries in prayer order, each as `{%Types.RosaryMystery{},
  updated_at}`, the second being the row's last change as a UTC
  `DateTime`.
  """
  @spec rows(keyword) :: [{Types.RosaryMystery.t(), DateTime.t()}]
  def rows(opts) do
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
       }, DateTime.from_naive!(mystery.updated_at, "Etc/UTC")}
    end)
  end
end
