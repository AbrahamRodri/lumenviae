defmodule LumenViae.Rosary.Types.NumberedPoints do
  @moduledoc """
  Numbered points under a heading.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :heading, :string, allow_nil?: false, description: "The heading, as written."

    field :items, {:array, Types.NumberedPoint},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The points, in order."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :numbered_points
end
