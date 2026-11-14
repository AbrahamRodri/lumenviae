defmodule LumenViae.Rosary.Types.SpiritualBookArchiveRecording do
  @moduledoc """
  A book's recording from an Internet Archive item rather than LibriVox:
  for each chapter, the item's files that read it, in order, each with an
  optional start and end in seconds that leave out spoken titles or a
  reader's notes. A client that knows this field plays it in place of the
  LibriVox recording; one that does not keeps `librivox_id`.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :item, :string,
      allow_nil?: false,
      description:
        "The Internet Archive item (`StorySoul`). A file is `https://archive.org/download/<item>/<name>`."

    field :credit, :string,
      allow_nil?: false,
      description: "Who made the recording and its licence, as printed (`read by ...`)."

    field :chapters, {:array, Types.SpiritualBookArchiveChapter},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The chapters it reads, by index from 0, in order. A chapter not listed has no recording."

    field :unread, {:array, :integer},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Chapters, by index from 0, this recording does not read (Story of a Soul's Prologue and Epilogue): show them with no audio."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :spiritual_book_archive_recording
end
