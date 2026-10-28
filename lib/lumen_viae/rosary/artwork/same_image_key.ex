defmodule LumenViae.Rosary.Artwork.SameImageKey do
  @moduledoc """
  Refuses to record variants made from a key that is no longer the
  record's: a painting replaced while the backfill was resizing the old
  one would otherwise offer variants that do not exist.

  The backfill reads its records at the start of a run that can last
  minutes, so the record it holds may be stale. The key is therefore
  checked twice: against the record in hand, for a clear error, and in the
  update itself, as a filter on the row written, so a painting replaced
  since the read leaves the update with no row to change.
  """
  use Ash.Resource.Change

  require Ash.Expr

  @impl true
  def change(changeset, _opts, _context) do
    made_from = Ash.Changeset.get_argument(changeset, :for_image_key)

    if made_from == changeset.data.image_key do
      Ash.Changeset.filter(changeset, Ash.Expr.expr(image_key == ^made_from))
    else
      Ash.Changeset.add_error(changeset,
        field: :image_key,
        message: "has changed since the variants were made"
      )
    end
  end
end
