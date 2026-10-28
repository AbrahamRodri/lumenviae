defmodule LumenViae.Rosary.Artwork.ResetVariantWidths do
  @moduledoc """
  Clears `image_variant_widths` when a write changes `image_key` without
  naming widths of its own, so a record never offers variants of a painting
  it no longer shows.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :image_key) and
         not Ash.Changeset.changing_attribute?(changeset, :image_variant_widths) do
      Ash.Changeset.force_change_attribute(changeset, :image_variant_widths, [])
    else
      changeset
    end
  end

  # Decided from the inputs alone, never from the stored row, so the same
  # answer holds inside an atomic update.
  @impl true
  def atomic(changeset, opts, context), do: {:ok, change(changeset, opts, context)}
end
