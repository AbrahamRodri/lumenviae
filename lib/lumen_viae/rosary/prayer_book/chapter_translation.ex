defmodule LumenViae.Rosary.PrayerBook.ChapterTranslation do
  @moduledoc """
  One chapter of the Prayer Book (a topic of the Prayers tab) in the
  language a read asked for, as the `chapter_translations` section of
  `GET /api/v2/prayer-book?lang=es` serves it, keyed by the chapter's id.
  Its Latin title and numeral have no translation. See
  `LumenViae.Rosary.PrayerBook.Spanish`.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The chapter's id, the same as in `chapters`."

    field :title, :string, allow_nil?: false, description: "Its title in this language."

    field :topic, :string,
      allow_nil?: false,
      description: "What it is about, in a few words, in this language (`Oraciones a María`)."

    field :note, :string,
      description: "Its one italic line in this language, or null where the English has none."

    field :section_titles, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Its sub-headings in this language, one per section, in the order of the chapter's `sections`."

    field :search_words, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Words a search in this language finds it by. Empty when none."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chapter_translation
end
