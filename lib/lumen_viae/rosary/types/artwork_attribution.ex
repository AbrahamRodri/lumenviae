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
    # Never null: artwork without a licence is not published at all.
    field :license, :string, allow_nil?: false
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :artwork_attribution
end
