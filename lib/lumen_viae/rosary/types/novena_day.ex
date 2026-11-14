defmodule LumenViae.Rosary.Types.NovenaDay do
  @moduledoc """
  One day of a novena: what is prayed that day, in order.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :number, :integer,
      allow_nil?: false,
      constraints: [min: 1],
      description: "Which day it is, from 1."

    field :title, :string,
      allow_nil?: false,
      description: "Its title (`Mary, who unties`)."

    field :parts, {:array, Types.NovenaPart},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "What is prayed, in order."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :novena_day
end
