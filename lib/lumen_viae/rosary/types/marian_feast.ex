defmodule LumenViae.Rosary.Types.MarianFeast do
  @moduledoc """
  A feast of Mary a Consecration can end on. Day 1 is 33 days before it;
  the device does the date arithmetic.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The feast's id (`assumption`). Stable forever: a device stores it."

    field :name, :string, allow_nil?: false, description: "Its name (`The Assumption`)."
    field :month, :integer, allow_nil?: false, description: "Its month, from 1 to 12."
    field :day, :integer, allow_nil?: false, description: "Its day of the month."

    field :description, :string,
      allow_nil?: false,
      description: "What it celebrates, in a few words."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :marian_feast
end
