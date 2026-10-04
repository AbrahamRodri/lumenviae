defmodule LumenViae.Rosary.Types.RosaryVerse do
  @moduledoc """
  The Scriptural Rosary's verse for one Hail Mary bead, as text.
  """
  use Ash.TypedStruct

  typed_struct do
    field :bead, :integer,
      allow_nil?: false,
      description: "The Hail Mary it is said before, counting from 1."

    field :reference, :string, allow_nil?: false, description: "Its citation: `Luke 1:26`."

    field :text, :string,
      allow_nil?: false,
      description:
        "The verse, in the original Douay-Rheims, exactly as the spoken Rosary says it."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_verse
end
