defmodule LumenViae.Rosary.PrayerBook.NovenaPartTranslation do
  @moduledoc """
  The words of one novena part in another language, by the part's `id`.
  See `LumenViae.Rosary.PrayerBook.NovenaTranslation`.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The part's `id` in `novenas` (`undoer_of_knots_d1_meditation`)."

    field :title, :string,
      description: "Its heading in this language, or null where the part has none."

    field :text, :string,
      allow_nil?: false,
      description:
        "Its words in this language, in the PrayerText grammar. They also stand in the twin prayer's translation, word for word."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :novena_part_translation
end
