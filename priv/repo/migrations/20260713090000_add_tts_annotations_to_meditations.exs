defmodule LumenViae.Repo.Migrations.AddTtsAnnotationsToMeditations do
  use Ecto.Migration

  def change do
    alter table(:meditations) do
      # Narration pause positions extracted from {pause:N} markers at import
      # time: a list of %{"offset" => grapheme_offset_into_content,
      # "seconds" => n} maps consumed only when generating ElevenLabs audio.
      add :tts_annotations, {:array, :map}, default: [], null: false
    end
  end
end
