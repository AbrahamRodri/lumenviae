defmodule LumenViae.Rosary.Types.NarrationLine do
  @moduledoc """
  One line of a meditation as a narration speaks it, and where it is in
  that recording: a sentence, or several the narrator read without a
  pause. The Chant Library's `ChantLine`, for the spoken word.
  """
  use Ash.TypedStruct

  typed_struct do
    field :text, :string,
      allow_nil?: false,
      description: "The words, as the meditation's text has them."

    field :start, :float, allow_nil?: false, description: "When it begins, in seconds."
    field :end, :float, allow_nil?: false, description: "When it ends, in seconds."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :narration_line
end
