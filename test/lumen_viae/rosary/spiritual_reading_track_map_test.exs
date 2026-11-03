defmodule LumenViae.Rosary.SpiritualReadingTrackMapTest do
  @moduledoc """
  The real recordings' tracks (LibriVox's feeds as served, in
  `test/support/fixtures/librivox/`) against the chapters the parser cuts
  from the real texts (`chapters.json`, the apps' cut of the five whole
  editions): the Android app's `LibraryTrackMapTest`, case for case, with
  the numerals the map reads.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.SpiritualReading.Parser
  alias LumenViae.Rosary.SpiritualReading.Recording
  alias LumenViae.Rosary.SpiritualReading.TrackMap
  alias LumenViae.Rosary.SpiritualReading.TrackMap.Alignment

  @fixtures "test/support/fixtures/librivox"

  defp chapters(book_id) do
    Path.join(@fixtures, "chapters.json")
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!(book_id)
    |> Enum.map(fn chapter ->
      %{id: chapter["id"], part: chapter["part"], heading: chapter["heading"]}
    end)
  end

  defp info(book_id),
    do: Enum.find(Library.served(:spiritual_reading, "books"), &(&1.id == book_id))

  defp tracks(librivox_id) do
    {:ok, tracks} =
      Path.join(@fixtures, "feed-#{librivox_id}.json")
      |> File.read!()
      |> Jason.decode!()
      |> Recording.read(librivox_id)

    tracks
  end

  defp align(book_id) do
    info = info(book_id)
    tracks = tracks(info.librivox_id)
    {TrackMap.align(chapters(book_id), tracks, info.track_mapping), tracks}
  end

  defp title(tracks, index), do: Enum.at(tracks, index).title

  test "the Story of a Soul reads a chapter a track, past the dedication" do
    {map, tracks} = align("story-of-a-soul")

    assert title(tracks, Alignment.track(map, 0)) == "Prologue: Parentage and Birth"
    assert title(tracks, Alignment.track(map, 1)) == "Earliest Memories"
    # The epilogue over two tracks is one reading, so the page cannot
    # follow either.
    assert Alignment.track(map, 12) == 13
    assert Alignment.chapters(map, 14) == 12..12
    refute Alignment.reads_whole_chapter?(map, 13)
    assert Alignment.reads_whole_chapter?(map, Alignment.track(map, 1))
  end

  test "the Confessions' books span several tracks" do
    {map, tracks} = align("confessions-of-st-augustine")

    assert title(tracks, Alignment.track(map, 0)) == "Book One, Chapters 1-10"
    assert title(tracks, Alignment.track(map, 1)) == "Book Two"
    assert Alignment.chapters(map, 1) == 0..0
    refute Alignment.reads_whole_chapter?(map, 0)
    assert Alignment.reads_whole_chapter?(map, 2)
    assert title(tracks, Alignment.track(map, 12)) == "Book Thirteen, Chapters 1-10"
  end

  test "Brother Lawrence passes over the preface the recording never reads" do
    {map, tracks} = align("practice-of-the-presence-of-god")

    assert Alignment.track(map, 0) == nil
    assert title(tracks, Alignment.track(map, 1)) == "First Conversation"
    assert title(tracks, Alignment.track(map, 5)) == "First Letter"
  end

  test "the Glories of Mary pass over the chapter the recording skips" do
    {map, tracks} = align("glories-of-mary")

    assert title(tracks, Alignment.track(map, 0)) == "Introduction"
    assert Alignment.track(map, 40) == nil
    assert Alignment.track(map, 41) == Alignment.track(map, 39) + 1
  end

  test "a part number in another script is no part, and never raises" do
    info = info("story-of-a-soul")

    tracks =
      for {title, i} <- Enum.with_index(["Chapter 1 Part \u0662", "Chapter 1 pt. \uFF17"]) do
        %{id: "#{i}", title: title, url: "https://www.archive.org/#{i}.mp3", seconds: 60}
      end

    assert %Alignment{} = TrackMap.align(chapters("story-of-a-soul"), tracks, info.track_mapping)
  end

  test "a book without a recording has no tracks" do
    info = info("imitation-of-christ")
    assert info.librivox_id == nil
    assert Alignment.empty?(TrackMap.align(chapters(info.id), [], info.track_mapping))

    none = %{kind: "none", offset: nil, unread: []}
    assert Alignment.empty?(TrackMap.align(chapters("story-of-a-soul"), tracks(8021), none))
  end

  test "a track's length and address" do
    {:ok, [track]} =
      Recording.read(
        %{
          "books" => [
            %{
              "sections" => [
                %{
                  "id" => "1",
                  "title" => "x",
                  "listen_url" => "http://www.archive.org/a.mp3",
                  "playtime" => "1:02:03"
                }
              ]
            }
          ]
        },
        1
      )

    assert track.url == "https://www.archive.org/a.mp3"
    assert track.seconds == 3723
    assert hd(tracks(564)).seconds == 242
  end

  test "a track naming a book and its chapters reads them" do
    # As the Imitation's would: Book 2 runs to 12 chapters, the track says 11-20.
    chapters =
      Enum.map(
        1..12,
        &%{part: "The First Book", heading: "Chapter #{TrackMap.roman_numeral(&1)}"}
      ) ++
        Enum.map(
          1..12,
          &%{part: "The Second Book", heading: "Chapter #{TrackMap.roman_numeral(&1)}"}
        )

    tracks =
      Enum.map(
        ["Book 1 - Chapters 1-12", "Book 2 - Chapters 1-10", "Book 2 - Chapters 11-20"],
        &%{title: &1}
      )

    map =
      TrackMap.align(chapters, tracks, %{kind: "book_chapter_ranges", offset: nil, unread: []})

    assert Alignment.track(map, 0) == 0
    assert Alignment.chapters(map, 0) == 0..11
    assert Alignment.track(map, 12) == 1
    assert Alignment.track(map, 22) == 2
    assert Alignment.track(map, 23) == 2
    assert Alignment.chapters(map, 2) == 22..23
    refute Alignment.reads_whole_chapter?(map, 2)
  end

  test "every chapter of every recorded book has its track, but those the catalogue says are unread" do
    for book_id <-
          ~w(story-of-a-soul confessions-of-st-augustine glories-of-mary practice-of-the-presence-of-god) do
      {map, tracks} = align(book_id)
      unread = info(book_id).track_mapping.unread

      for chapter <- chapters(book_id), chapter.id not in unread do
        track = Alignment.track(map, chapter.id)

        assert (is_integer(track) and track < length(tracks)) or
                 (book_id == "practice-of-the-presence-of-god" and chapter.id == 0),
               "#{book_id} chapter #{chapter.id} (#{chapter.heading}) has no track"
      end
    end
  end

  test "the web's parser cuts Brother Lawrence as the apps do, so the alignment holds" do
    info = info("practice-of-the-presence-of-god")
    text = File.read!("test/support/fixtures/gutenberg/pg13871.txt")
    text = if String.valid?(text), do: text, else: :unicode.characters_to_binary(text, :latin1)

    cut = Parser.parse(text, info).chapters |> Enum.map(&Map.take(&1, [:id, :part, :heading]))
    assert cut == chapters(info.id)
  end

  describe "numerals" do
    test "read in every form the sources write them" do
      assert TrackMap.number("Chapter XI") == 11
      assert TrackMap.number("Book 3 - Chapters 1-10") == 3
      assert TrackMap.number("The First Book") == 1
      assert TrackMap.book_number("Book Four, Chapters 1-10") == 4
      assert TrackMap.book_number("Chapters 1-10 of Book IV") == 4
      assert TrackMap.book_number("Chapter 3") == nil
    end

    test "a word spelled in a numeral's letters is not one" do
      assert TrackMap.roman("XIV") == 14
      assert TrackMap.roman("XIV.") == 14
      for word <- ~w(DID CIVIL MIX IIII i VV), do: assert(TrackMap.roman(word) == nil)
    end
  end
end
