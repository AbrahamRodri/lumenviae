defmodule LumenViae.Rosary.Artwork.SameImageKey do
  @moduledoc """
  Refuses to record variants made from a key that is no longer the
  record's: a painting replaced while the backfill was resizing the old
  one would otherwise offer variants that do not exist.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    made_from = Ash.Changeset.get_argument(changeset, :for_image_key)

    if made_from == changeset.data.image_key do
      :ok
    else
      {:error, field: :image_key, message: "has changed since the variants were made"}
    end
  end
end
