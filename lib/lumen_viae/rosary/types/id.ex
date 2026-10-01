defmodule LumenViae.Rosary.Types.Id do
  @moduledoc """
  An integer id that GraphQL calls an `ID`, so a field naming another
  record's id has the same type as that record's own `id`. On the wire an
  `ID` is a string ("42"); a client may send either form back.
  """
  use Ash.Type.NewType, subtype_of: :integer

  def graphql_type(_), do: :id
  def graphql_input_type(_), do: :id
end
