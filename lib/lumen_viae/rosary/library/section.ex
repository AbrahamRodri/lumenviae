defmodule LumenViae.Rosary.Library.Section do
  @moduledoc """
  One section of a `LumenViae.Rosary.Library` document: `document` and
  `section` name it (`:prayer_book`, `"prayers"`). The section was cast to
  its type once, as `Library` compiled, so a request only hands it over.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.Types

  # Each section's type, by document.
  @types %{
    prayer_book: %{"prayers" => Types.BookPrayer, "chapters" => Types.PrayerBookChapter},
    chant_library: %{"groups" => Types.ChantGroup, "chants" => Types.Chant},
    consecration: %{
      "phases" => Types.ConsecrationPhase,
      "days" => Types.ConsecrationDay,
      "prayers" => Types.ConsecrationPrayer,
      "feasts" => Types.MarianFeast
    }
  }

  @impl true
  def calculate(records, opts, _context) do
    value = Library.served(opts[:document], opts[:section])

    Enum.map(records, fn _record -> value end)
  end

  @doc """
  A document's section (`:prayer_book`, `"prayers"`) cast to its type, as
  it will be served. A type trims text and reads `""` as null, so a section the cast
  would change is an error naming the section and the items it would
  change: what a request serves must be what the file holds, word for
  word, and the version that fingerprints the file must fingerprint it.
  """
  @spec cast(Library.document(), String.t(), [map]) :: {:ok, [struct]} | {:error, String.t()}
  def cast(document, name, items) do
    type = @types |> Map.fetch!(document) |> Map.fetch!(name)

    case Ash.Type.cast_input({:array, type}, items, nil_items?: false) do
      {:ok, cast} ->
        changed =
          for {served, held} <- Enum.zip(plain(cast), items),
              served != held,
              do: held["id"] || held["number"] || held["title"]

        if changed == [],
          do: {:ok, cast},
          else:
            {:error,
             "#{name} would not be served as written (text with spaces at either end, or empty text): #{Enum.join(changed, ", ")}"}

      {:error, error} ->
        {:error, "#{name} does not fit its type: #{inspect(error)}"}
    end
  end

  @doc """
  A cast section as plain data again, string keys throughout, to compare
  with what the file holds.
  """
  @spec plain(term) :: term
  def plain(list) when is_list(list), do: Enum.map(list, &plain/1)

  def plain(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {to_string(key), plain(value)} end)
  end

  def plain(value), do: value
end
