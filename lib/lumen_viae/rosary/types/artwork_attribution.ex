defmodule LumenViae.Rosary.Types.ArtworkAttribution do
  @moduledoc """
  Where a painting came from: title, artist, year, source and licence.
  `year` is a string ("c. 1505", "1601-02"), never a number.
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string
    field :artist, :string
    field :year, :string
    field :source_url, :string
    field :license, :string
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :artwork_attribution
end
