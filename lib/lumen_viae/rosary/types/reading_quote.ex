defmodule LumenViae.Rosary.Types.ReadingQuote do
  @moduledoc """
  A saying set apart in a reading, with its source.
  """
  use Ash.TypedStruct

  typed_struct do
    field :text, :string, allow_nil?: false, description: "The words."
    field :citation, :string, allow_nil?: false, description: "Whose, and where."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :reading_quote
end
