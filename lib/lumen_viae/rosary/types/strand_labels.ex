defmodule LumenViae.Rosary.Types.StrandLabels do
  @moduledoc """
  The labels drawn beside the strand: Hail Mary beads carry none.
  """
  use Ash.TypedStruct

  typed_struct do
    field :our_father, :string,
      allow_nil?: false,
      description: "Beside an Our Father bead; `{decade}` is the decade's number, counted from 1."

    field :amen, :string, allow_nil?: false, description: "Beside the final bead."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :strand_labels
end
