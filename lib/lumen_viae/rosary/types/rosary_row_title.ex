defmodule LumenViae.Rosary.Types.RosaryRowTitle do
  @moduledoc """
  What a row beneath the choices is called.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "`audio`, `mysteries` or `voice`."

    field :title, :string,
      allow_nil?: false,
      description: "The row's name."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_row_title
end
