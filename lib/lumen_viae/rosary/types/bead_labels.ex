defmodule LumenViae.Rosary.Types.BeadLabels do
  @moduledoc """
  What the bead under the hand is called. `{n}` is the Hail Mary's number.
  """
  use Ash.TypedStruct

  typed_struct do
    field :our_father, :string, allow_nil?: false, description: "An Our Father bead."

    field :hail_mary, :string, allow_nil?: false, description: "Hail Mary n's bead."

    field :glory_be, :string, allow_nil?: false, description: "The Glory Be's bead."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :bead_labels
end
