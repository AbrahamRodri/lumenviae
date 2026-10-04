defmodule LumenViae.Rosary.Types.GuidedMysteries do
  @moduledoc """
  The guided Rosary of one set of mysteries.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :category, :string, allow_nil?: false, description: "A category slug."

    field :steps, {:array, Types.GuidedStep},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Every step, in order: 75 for a Rosary of five decades. A step is known by its place in the list, from 0."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :guided_mysteries
end
