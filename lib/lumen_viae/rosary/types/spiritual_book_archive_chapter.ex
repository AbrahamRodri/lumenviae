defmodule LumenViae.Rosary.Types.SpiritualBookArchiveChapter do
  @moduledoc """
  One chapter of an Internet Archive recording: the files that read it,
  played one after another.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :chapter, :integer,
      allow_nil?: false,
      constraints: [min: 0],
      description: "The chapter, by index from 0, as the text is cut (`parsing`)."

    field :files, {:array, Types.SpiritualBookArchiveFile},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The item's files that read it, in the order they are played."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :spiritual_book_archive_chapter
end
