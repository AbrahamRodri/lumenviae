defmodule LumenViae.Office.Types.Celebration do
  @moduledoc """
  What a day keeps: the feast or feria's title and, when the engine gives
  one, its rank as the engine spells it ("Duplex II. classis").
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string, allow_nil?: false
    field :rank, :string
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :office_celebration
end
