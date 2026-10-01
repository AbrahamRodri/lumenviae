defmodule LumenViae.Rosary.Meditation.ResetStaleAnnotations do
  @moduledoc """
  Clears a meditation's narration pauses when its content changes and no
  fresh ones arrive with it.

  Annotation offsets index into the content they were extracted from, so
  they cannot survive a content edit. An edit that supplies its own
  annotations (the CSV update does, having just extracted them from the new
  text) keeps them, even when they happen to equal the old ones.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :content) and
         not annotations_supplied?(changeset) do
      Ash.Changeset.force_change_attribute(changeset, :tts_annotations, [])
    else
      changeset
    end
  end

  defp annotations_supplied?(%{params: params}) do
    Map.has_key?(params, :tts_annotations) or Map.has_key?(params, "tts_annotations")
  end
end
