defmodule LumenViae.Rosary.Types.ChantOccasionStep do
  @moduledoc """
  One chant of an occasion, sung `times` over (`ChantOccasionStep` in the
  iOS app): the Ave Maria ten times in a decade.
  """
  use Ash.TypedStruct

  typed_struct do
    field :kind, :string,
      allow_nil?: false,
      description:
        "`chant` (the chant `chant_id`) or `antiphon_of_the_season`: tonight's song to Mary, the first chant whose `prayer_ids` hold the Prayer Book's antiphon of the season (`marian_antiphons`) on that day."

    field :chant_id, :string, description: "For `chant`: the chant. Null otherwise."

    field :times, :integer,
      allow_nil?: false,
      description: "How many times it is sung, 1 or more."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_occasion_step
end
