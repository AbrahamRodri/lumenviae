defmodule LumenViae.Rosary.Types.SpiritualBookArchiveFile do
  @moduledoc """
  One file of an Internet Archive recording, and the part of it to play.
  """
  use Ash.TypedStruct

  typed_struct do
    field :name, :string,
      allow_nil?: false,
      description: "The file's name in the item (`storysoul02b_64kb.mp3`)."

    field :start, :float,
      constraints: [min: 0],
      description: "Where to begin, in seconds, or null for the beginning."

    field :end, :float,
      constraints: [min: 0],
      description:
        "Where to stop, in seconds, or null for the end of the file. What follows (a reader's notes) is not the book's text."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :spiritual_book_archive_file
end
