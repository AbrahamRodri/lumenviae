defmodule LumenViae.Rosary.PrayerBook.Current do
  @moduledoc """
  Answers a `LumenViae.Rosary.PrayerBook` read with the one document there
  is, as `LumenViae.Rosary.Library.Current` does for the other library
  documents, and in the language the read asked for (`lang`).

  In English the version and date are `Library.stamp(:prayer_book)`'s,
  exactly as before Spanish was served. In Spanish the translations are
  folded into the version and their date into the date, so a Spanish word
  changed moves both.
  """
  use Ash.Resource.Preparation

  alias Ash.DataLayer.Simple
  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.PrayerBook.Spanish

  @impl true
  def prepare(query, _opts, _context) do
    lang = query |> Ash.Query.get_argument(:lang) |> Content.language()
    stamp = stamp(lang)

    record = struct(query.resource, stamp |> Map.put(:id, "current") |> Map.put(:lang, lang))

    Simple.set_data(query, [record])
  end

  @doc "The document's `version` and `updated_at` in a language."
  @spec stamp(String.t()) :: %{version: String.t(), updated_at: DateTime.t()}
  def stamp("es") do
    %{version: version, updated_at: updated_at} = Library.stamp(:prayer_book)

    %{
      version: Content.version(%{"book" => version, "translations" => Spanish.prayers()}),
      updated_at: Enum.max([updated_at, Spanish.updated_at()], DateTime)
    }
  end

  def stamp(_lang), do: Library.stamp(:prayer_book)
end
