defmodule LumenViae.Rosary.MeditationSet.PublishedArtwork do
  @moduledoc """
  The artwork a set is shown with, for the GraphQL API: the set's own
  painting when it is publishable, otherwise its linked author's portrait,
  otherwise null. The same choice as the REST API's image fields, made by
  the same function, `LumenViae.Rosary.artwork_record/1`, and gated the
  same way: artwork without alt text and a licence is not published.
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

  # GraphQL selects only the fields a query names, and every image column
  # is private, so the calculation asks for them itself, on the set and on
  # its author.
  @impl true
  def load(_query, _opts, _context), do: @fields ++ [author_profile: @fields]

  @impl true
  def calculate(sets, _opts, _context) do
    Enum.map(sets, fn set ->
      case Rosary.artwork_record(set) do
        nil -> nil
        record -> artwork(record)
      end
    end)
  end

  defp artwork(record) do
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
