defmodule LumenViae.Rosary.MeditationSet.NormalizeLabels do
  @moduledoc """
  Keeps a set's labels deduplicated while preserving the curated order.

  Labels are matched by the iOS app as exact case-sensitive strings and the
  first label is the set's primary group, so a repeat is dropped where it
  stands rather than the list being sorted. Clearing the labels stores an
  empty list, never null: the column is NOT NULL and the app decodes an
  array.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_change(changeset, :labels) do
      {:ok, nil} -> Ash.Changeset.force_change_attribute(changeset, :labels, [])
      {:ok, labels} -> Ash.Changeset.force_change_attribute(changeset, :labels, Enum.uniq(labels))
      :error -> changeset
    end
  end
end
