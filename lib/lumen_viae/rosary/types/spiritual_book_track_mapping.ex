defmodule LumenViae.Rosary.Types.SpiritualBookTrackMapping do
  @moduledoc """
  How a book's LibriVox tracks line up with its chapters
  (`LibraryTrackMapping` in the iOS app, whose `LibraryTrackMap` does the
  aligning).
  """
  use Ash.TypedStruct

  typed_struct do
    field :kind, :string,
      allow_nil?: false,
      description:
        "`none` (no recording, or one whose tracks cannot be tied to the chapters), `sequential` (track `chapter + offset` reads the chapter, one for one; tracks titled `... Part 1`, `... Part 2` count as one), `book_chapter_ranges` (a track's title names a part and a span of chapters, `Book 3 - Chapters 21-30`; a chapter plays the track that holds it, from its start) or `book_spans` (a chapter is a whole book read over several tracks; it plays from the first track that names it)."

    field :offset, :integer,
      description:
        "For `sequential`: added to a chapter's index to give its track. Positive for front-matter tracks the text does not have; negative for chapters the text opens with that have no track (Brother Lawrence's preface). Null otherwise."

    field :unread, {:array, :integer},
      allow_nil?: false,
      description:
        "For `sequential`: chapters, by index from 0, the recording passes over (read into another chapter's track); the count carries on past them. Empty otherwise."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :spiritual_book_track_mapping
end
