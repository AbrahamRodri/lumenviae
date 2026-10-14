defmodule LumenViae.Rosary.Types.ChantLine do
  @moduledoc """
  One line of a chant as it is sung, with its English and its place in the
  recording.
  """
  use Ash.TypedStruct

  typed_struct do
    field :latin, :string, allow_nil?: false, description: "The Latin, as sung."
    field :english, :string, allow_nil?: false, description: "The English beside it."
    field :start, :float, allow_nil?: false, description: "When it begins, in seconds."
    field :end, :float, allow_nil?: false, description: "When it ends, in seconds."

    field :part, :integer,
      description:
        "The score page it is sung from (an index into the chant's `score`, counting from 0), or null when the chant does not say."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_line
end
