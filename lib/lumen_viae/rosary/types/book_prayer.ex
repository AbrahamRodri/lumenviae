defmodule LumenViae.Rosary.Types.BookPrayer do
  @moduledoc """
  One prayer of the Prayer Book, as `GET /api/v2/prayer-book` serves it.
  See `LumenViae.Rosary.Library` for where the words live.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description:
        "The prayer's id (`sub_tuum`). Stable forever: a device stores it for saved prayers."

    field :title, :string, allow_nil?: false, description: "The prayer's title on its own page."

    field :latin_title, :string,
      description:
        "Its name in the Church's own tongue (`Sub tuum praesidium`), or null for a prayer composed in English."

    field :origin, :string,
      description: "Who wrote it and when, as a prayer book's small print, or null."

    field :note, :string, description: "When or how it is said, in one plain sentence, or null."

    field :english, :string,
      allow_nil?: false,
      description:
        "The words, in the app's PrayerText grammar: one line per paragraph, versicles and responses marked, a rubric in square brackets."

    field :latin, :string,
      description:
        "The Latin, or null when the prayer has none. It pairs with the English line for line, blank lines included."

    field :list_title, :string,
      description: "Its name in a list (`Hail Mary`), or null to use the title."

    field :english_name, :string,
      description:
        "The English name set small beneath a prayer known by its Latin one (`Memorare`), or null."

    field :search_words, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Other names it is looked for by, beside its titles. Empty when none."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :book_prayer
end
