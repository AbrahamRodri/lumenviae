defmodule LumenViaeWeb.API.ArtworkJSON do
  @moduledoc """
  The artwork block, shared by every response that can carry a painting.

  Building an artwork URL is pure string work with no signing and no I/O, so
  it belongs in the view rather than the controller: nothing has to be
  prepared before rendering and no controller changes as artwork spreads to
  more endpoints.

  Every key is null when a set has no servable artwork, so the client
  branches on `image_url` alone and a half-populated catalogue degrades one
  set at a time.
  """

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork

  @absent %{
    image_url: nil,
    image_alignment: nil,
    image_focal_x: nil,
    image_focal_y: nil,
    image_width: nil,
    image_height: nil,
    image_alt: nil,
    image_attribution: nil
  }

  @doc """
  Renders the artwork block for a record, or the absent block.

  Artwork is served only when it has both alt text and a licence.
  Describing the painting is what makes the hero usable with VoiceOver, and
  recording where it came from is what keeps the project honest about
  provenance; artwork with neither is not ready to be published, whatever
  entry point uploaded it.
  """
  def data(record) do
    if Artwork.publishable?(record) do
      %{
        image_url: Rosary.artwork_url(record),
        image_alignment: Artwork.alignment(record.image_focal_y),
        image_focal_x: record.image_focal_x,
        image_focal_y: record.image_focal_y,
        image_width: record.image_width,
        image_height: record.image_height,
        image_alt: record.image_alt,
        image_attribution: attribution(record)
      }
    else
      @absent
    end
  end

  @doc """
  The keys this block contributes, all null. Public so a caller can render a
  record that carries no artwork columns at all.
  """
  def absent, do: @absent

  defp attribution(record) do
    %{
      title: record.image_title,
      artist: record.image_artist,
      year: record.image_year,
      source_url: record.image_source_url,
      license: record.image_license
    }
  end
end
