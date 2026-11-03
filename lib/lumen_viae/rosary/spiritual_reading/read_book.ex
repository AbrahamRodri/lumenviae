defmodule LumenViae.Rosary.SpiritualReading.ReadBook do
  @moduledoc """
  `SpiritualReading`'s `:book` action: a book of the shelf as the website
  reads it, its text fetched from Project Gutenberg by the server and cut
  into chapters (`LumenViae.Rosary.SpiritualReading.Text`).

  Answers a map whose `status` says what came of it, rather than an error,
  because each outcome is a page the reader sees: `:ok` with the book's
  `fingerprint`, its `contents` (each chapter's `id`, `part`, `heading` and
  `title`) and, when one was asked for by its index from 0, the `chapter`
  with its `paragraphs` and `notes`; `:not_found` for a book or chapter the
  shelf does not have; `:unreachable` when Gutenberg could not be reached
  (worth trying again); `:unreadable` when its edition no longer cuts into
  chapters (not worth it); and, when `cached_only` is set, `:cold` for a
  book this machine has not fetched yet, so a page can show at once and
  fetch it after it connects.
  """
  use Ash.Resource.Actions.Implementation

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.SpiritualReading.Text

  @impl true
  def run(input, _opts, _context) do
    book_id = input.arguments.book_id
    index = Map.get(input.arguments, :chapter)
    opts = [fetch: not Map.get(input.arguments, :cached_only, false)]

    case Enum.find(Library.served(:spiritual_reading, "books"), &(&1.id == book_id)) do
      nil -> {:ok, %{status: :not_found}}
      info -> {:ok, read(info, index, opts)}
    end
  end

  defp read(info, index, opts) do
    with {:ok, contents} <- Text.contents(info, opts),
         {:ok, chapter} <- chapter(info, index, opts) do
      %{
        status: :ok,
        fingerprint: contents.fingerprint,
        contents: contents.chapters,
        chapter: chapter
      }
    else
      {:error, reason} -> %{status: reason}
    end
  end

  defp chapter(_info, nil, _opts), do: {:ok, nil}
  defp chapter(info, index, opts), do: Text.chapter(info, index, opts)
end
