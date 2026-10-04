defmodule LumenViae.Rosary.Types.PendantPlace do
  @moduledoc """
  A place on the pendant, where the opening and closing prayers are said.
  """
  use Ash.TypedStruct

  typed_struct do
    field :place, :string,
      allow_nil?: false,
      description: "`cross`, `large_bead`, `small_bead_1` to `small_bead_3`, `chain` or `medal`."

    field :name, :string,
      allow_nil?: false,
      description: "What it is called, for a screen reader."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :pendant_place
end
