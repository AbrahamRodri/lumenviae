defmodule LumenViae.Rosary.Types.Artwork do
  @moduledoc """
  The painting a set is shown with, as one object rather than the REST
  API's eight flat `image_*` keys: present when there is servable artwork
  and null when there is none, so a client branches on one field.

  `url` is the public, unsigned, cacheable address of the image; it never
  expires. `variants` are smaller WebP copies of it, narrowest first,
  only those known to be stored (often none): draw the smallest at least as
  wide as needed, else `url`. `alignment` is the coarse "top" | "center" | "bottom" derived
  from the focal point; `focal_x` and `focal_y` are the point itself, each
  between 0 and 1.
  """
  use Ash.TypedStruct

  typed_struct do
    field :url, :string, allow_nil?: false
    field :alignment, :string, allow_nil?: false
    field :focal_x, :float, allow_nil?: false
    field :focal_y, :float, allow_nil?: false
    field :width, :integer
    field :height, :integer
    field :alt, :string, allow_nil?: false
    field :attribution, LumenViae.Rosary.Types.ArtworkAttribution, allow_nil?: false
    field :variants, {:array, LumenViae.Rosary.Types.ArtworkVariant}
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :artwork
end
