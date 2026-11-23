defmodule LumenViae.Rosary.Types.ArtworkVariant do
  @moduledoc """
  One WebP copy of a painting at a smaller width, stored beside the
  original: `width` in pixels and its public `url`. Only copies known to be
  in storage are listed (`image_variant_widths`), so a client can draw the
  smallest one at least as wide as it needs and fall back to the
  artwork's `url`.
  """
  use Ash.TypedStruct

  typed_struct do
    field :width, :integer, allow_nil?: false
    field :url, :string, allow_nil?: false
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :artwork_variant
end
