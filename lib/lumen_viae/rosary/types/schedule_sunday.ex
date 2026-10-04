defmodule LumenViae.Rosary.Types.ScheduleSunday do
  @moduledoc """
  Sunday's category in each season the Rosary schedule distinguishes.
  """
  use Ash.TypedStruct

  typed_struct do
    field :advent, :string, allow_nil?: false, description: "A Sunday of Advent."
    field :lent, :string, allow_nil?: false, description: "A Sunday of Lent."

    field :ordinary, :string,
      allow_nil?: false,
      description: "Any other Sunday, Christmastide and Eastertide included."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :schedule_sunday
end
