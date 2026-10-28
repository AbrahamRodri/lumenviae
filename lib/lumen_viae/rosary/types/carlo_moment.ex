defmodule LumenViae.Rosary.Types.CarloMoment do
  @moduledoc """
  One moment on St. Carlo's timeline, opening the chapter of his life it
  belongs to.
  """
  use Ash.TypedStruct

  typed_struct do
    field :year, :string, allow_nil?: false, description: "The year (`1998`)."
    field :title, :string, allow_nil?: false, description: "What happened (`First Communion`)."
    field :line, :string, allow_nil?: false, description: "One line more."

    field :reading_id, :string,
      allow_nil?: false,
      description: "The reading on the `life` shelf it opens."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :carlo_moment
end
