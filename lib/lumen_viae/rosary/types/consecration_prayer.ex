defmodule LumenViae.Rosary.Types.ConsecrationPrayer do
  @moduledoc """
  One prayer of the Consecration, in the words the Consecration says it.
  Its id is the Prayer Book's where the book has the prayer, but the
  words are the Consecration's own: its Glory Be is the chanted setting.
  A sung prayer's chant is the first Chant Library chant whose
  `prayer_ids` names this id.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The prayer's id (`veni_creator`). Stable forever."

    field :title, :string, allow_nil?: false, description: "Its English title."

    field :latin_title, :string,
      description: "Its Latin title (`Veni Creator Spiritus`), or null."

    field :english, :string,
      allow_nil?: false,
      description:
        "The words, in the app's PrayerText grammar: one line per paragraph, versicles and responses marked, a rubric in square brackets."

    field :latin, :string,
      description:
        "The Latin, or null for a prayer said in English alone. It pairs with the English line for line, blank lines included."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :consecration_prayer
end
