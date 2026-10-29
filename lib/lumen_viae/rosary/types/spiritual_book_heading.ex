defmodule LumenViae.Rosary.Types.SpiritualBookHeading do
  @moduledoc """
  One chapter whose printed heading a book replaces
  (`headingOverrides` in the iOS app).
  """
  use Ash.TypedStruct

  typed_struct do
    field :chapter, :integer, allow_nil?: false, description: "The chapter, by index from 0."
    field :heading, :string, allow_nil?: false, description: "The heading shown instead."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :spiritual_book_heading
end
