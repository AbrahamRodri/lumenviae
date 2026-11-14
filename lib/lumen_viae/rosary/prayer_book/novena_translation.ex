defmodule LumenViae.Rosary.PrayerBook.NovenaTranslation do
  @moduledoc """
  One novena in the language a read asked for, as the `novena_translations`
  section of `GET /api/v2/prayer-book?lang=es` serves it: the words the
  novena holds of its own, keyed by the ids `novenas` gives them. A part
  that names a book prayer takes that prayer's `translations` entry, and a
  `rosary` part has no words. See `LumenViae.Rosary.PrayerBook.Spanish`.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.PrayerBook.NovenaPartTranslation

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The novena's id, the same as in `novenas`."

    field :title, :string, allow_nil?: false, description: "Its title in this language."

    field :list_title, :string,
      description: "A shorter name for a list in this language, or null to use `title`."

    field :detail, :string,
      allow_nil?: false,
      description: "Its one sentence for its card, in this language."

    field :note, :string, description: "Its note in this language, or null."
    field :origin, :string, description: "Where its words come from, in this language, or null."

    field :search_words, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Words a search in this language finds it by."

    field :day_titles, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Each day's title in this language, day 1 first: one per day of `novenas`."

    field :parts, {:array, NovenaPartTranslation},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The words of its parts in this language, each once, by the part `id` `novenas` gives them. A part not listed keeps its English."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :novena_translation
end
