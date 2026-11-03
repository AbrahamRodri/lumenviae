defmodule LumenViae.Rosary.SpiritualReading.ReadRecording do
  @moduledoc """
  `SpiritualReading`'s `:recording` action: a book's LibriVox recording as
  the website plays it, its track list fetched from LibriVox by the server
  (`LumenViae.Rosary.SpiritualReading.Recording`) and lined up with the
  chapters cut from its text (`LumenViae.Rosary.SpiritualReading.TrackMap`,
  the app's `LibraryTrackMap`).

  Answers a map whose `status` says what came of it: `:ok` with the
  `tracks` and, by chapter index, how the recording reads each chapter;
  `:none` for a book with no recording; `:not_found` for a book the shelf
  does not have; `:unavailable` when the track list (or the book's text,
  which the alignment needs) could not be had; and, when `cached_only` is
  set, `:cold` for one this machine has not fetched yet.

  With `:ok`, each track is `%{id:, title:, url:, seconds:, chapter:}`,
  `chapter` the index of the one chapter it reads whole (the only kind the
  page may follow along with), or nil; and `chapters` is a list by chapter
  index of `%{track:, from:, whole?:}` (the track that reads it, the
  chapter that track opens with, whether it reads this chapter whole), or
  nil where no track reads the chapter.
  """
  use Ash.Resource.Actions.Implementation

  require Logger

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.SpiritualReading.Recording
  alias LumenViae.Rosary.SpiritualReading.Text
  alias LumenViae.Rosary.SpiritualReading.TrackMap
  alias LumenViae.Rosary.SpiritualReading.TrackMap.Alignment

  @impl true
  def run(input, _opts, _context) do
    book_id = input.arguments.book_id
    fetch? = not Map.get(input.arguments, :cached_only, false)

    case Enum.find(Library.served(:spiritual_reading, "books"), &(&1.id == book_id)) do
      nil -> {:ok, %{status: :not_found}}
      %{librivox_id: nil} -> {:ok, %{status: :none}}
      %{track_mapping: %{kind: "none"}} = info -> {:ok, read(info, fetch?, false)}
      info -> {:ok, read(info, fetch?, true)}
    end
  end

  defp read(info, fetch?, aligned?) do
    with {:ok, contents} <- contents(info, fetch?),
         {:ok, tracks} <- Recording.tracks(info, fetch: fetch?) do
      # A track that can't be played would leave a hole iOS doesn't have,
      # so the book is then heard track by track, never lined up with
      # the wrong chapters.
      whole_list? = Enum.all?(tracks, & &1.url)

      alignment =
        if aligned? and whole_list?,
          do: TrackMap.align(contents.chapters, tracks, info.track_mapping),
          else: Alignment.empty()

      tracks = Enum.filter(tracks, & &1.url)

      %{
        status: :ok,
        tracks:
          tracks
          |> Enum.with_index()
          |> Enum.map(fn {track, index} -> Map.put(track, :chapter, whole(alignment, index)) end),
        chapters:
          Enum.map(contents.chapters, fn chapter -> reading(alignment, chapter.id, tracks) end)
      }
    else
      {:error, :cold} -> %{status: :cold}
      {:error, _reason} -> %{status: :unavailable}
    end
  rescue
    # The feed's data never takes the book's pages down with it.
    exception ->
      Logger.error("A recording's alignment raised: #{Exception.message(exception)}")
      %{status: :unavailable}
  end

  defp contents(info, fetch?) do
    case Text.contents(info, fetch: fetch?) do
      {:ok, contents} -> {:ok, contents}
      {:error, :cold} -> {:error, :cold}
      {:error, _reason} -> {:error, :unavailable}
    end
  end

  defp whole(alignment, track) do
    if Alignment.reads_whole_chapter?(alignment, track),
      do: Alignment.first_chapter(alignment, track)
  end

  defp reading(alignment, index, tracks) do
    with track when is_integer(track) and track < length(tracks) <-
           Alignment.track(alignment, index) do
      %{
        track: track,
        from: Alignment.first_chapter(alignment, track),
        whole?:
          Alignment.reads_whole_chapter?(alignment, track) and
            Alignment.first_chapter(alignment, track) == index
      }
    else
      _none -> nil
    end
  end
end
