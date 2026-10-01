defmodule LumenViae.Office.Types.Choice do
  @moduledoc """
  One value a client may pass for a version, hour or language: the slug
  it sends and the label it shows.
  """
  use Ash.TypedStruct

  typed_struct do
    field :slug, :string, allow_nil?: false
    field :label, :string, allow_nil?: false
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :office_choice
end
