defmodule LumenViae.Rosary.Types.NumberedPoint do
  @moduledoc """
  A numbered point of advice: "II · Picture it · Place yourself in the scene."
  """
  use Ash.TypedStruct

  typed_struct do
    field :numeral, :string, allow_nil?: false, description: "Its numeral as shown (`I`, `II`)."
    field :title, :string, allow_nil?: false, description: "Its few words."
    field :text, :string, allow_nil?: false, description: "What it says."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :numbered_point
end
