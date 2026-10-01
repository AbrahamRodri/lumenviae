defmodule LumenViae.Office.Types.Source do
  @moduledoc """
  Where an hour's text came from. Every hour names it, because the texts
  are the Divinum Officium project's work, not ours.
  """
  use Ash.TypedStruct

  typed_struct do
    field :name, :string, allow_nil?: false
    field :url, :string, allow_nil?: false
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :office_source
end
