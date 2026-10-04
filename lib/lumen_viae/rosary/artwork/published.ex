defmodule LumenViae.Rosary.Artwork.Published do
  @moduledoc """
  The painting a record carrying `LumenViae.Rosary.Artwork.Fragment` is
  shown with, as `LumenViae.Rosary.Types.Artwork`: its own artwork when it
  is publishable (an image, alt text and a licence), and null otherwise.
  A mystery's painting and a category's card are served through it.

  `shape/1` is the one place a record's artwork columns become the API's
  artwork object; `MeditationSet.PublishedArtwork`, which falls back to a
  set's author, uses it too.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork
  alias LumenViae.Rosary.Types

  @fields [
    :image_key,
    :image_width,
    :image_height,
    :image_focal_x,
    :image_focal_y,
    :image_alt,
    :image_title,
    :image_artist,
    :image_year,
    :image_source_url,
    :image_license
  ]

  @doc "The artwork columns a published painting is read from."
  @spec fields() :: [atom]
  def fields, do: @fields

  # The image columns are private, so an API selecting only this field
  # would not read them: the calculation asks for them itself.
  @impl true
  def load(_query, _opts, _context), do: @fields

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      if Artwork.publishable?(record), do: shape(record)
    end)
  end

  @doc "A record's artwork columns as the API's artwork object."
  @spec shape(map) :: Types.Artwork.t()
  def shape(record) do
    %Types.Artwork{
      url: Rosary.artwork_url(record),
      alignment: Artwork.alignment(record.image_focal_y),
      focal_x: record.image_focal_x,
      focal_y: record.image_focal_y,
      width: record.image_width,
      height: record.image_height,
      alt: record.image_alt,
      attribution: %Types.ArtworkAttribution{
        title: record.image_title,
        artist: record.image_artist,
        year: record.image_year,
        source_url: record.image_source_url,
        license: record.image_license
      }
    }
  end
end
