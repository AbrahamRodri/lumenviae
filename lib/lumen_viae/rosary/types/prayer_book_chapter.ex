defmodule LumenViae.Rosary.Types.PrayerBookChapter do
  @moduledoc """
  A chapter of the Prayer Book, as its contents page prints it.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string, allow_nil?: false, description: "The chapter's id. Stable forever."
    field :numeral, :string, allow_nil?: false, description: "Its Roman numeral (`IV`)."
    field :title, :string, allow_nil?: false, description: "Its title."
    field :latin_title, :string, allow_nil?: false, description: "Its Latin title."
    field :note, :string, description: "The chapter's one italic line, or null."
    field :topic, :string, description: "What it is about, in a few words, or null."

    field :search_words, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Other words it is looked for by. Empty when none."

    field :prayer_ids, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Its prayers in the chapter's order, each once: the union of its sections' prayers. Every id is one of the document's prayers."

    field :sections, {:array, Types.PrayerBookSection},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its sub-headings in order, each with its prayers."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :prayer_book_chapter
end
