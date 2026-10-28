defmodule LumenViae.Rosary.Types.ReadingPart do
  @moduledoc """
  A named part of a library reading, set after its prose: a heading, then
  a paragraph.
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string, allow_nil?: false, description: "Its heading."
    field :text, :string, allow_nil?: false, description: "Its prose."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :reading_part
end
