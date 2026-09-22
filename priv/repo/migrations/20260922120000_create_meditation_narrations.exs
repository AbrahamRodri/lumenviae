defmodule LumenViae.Repo.Migrations.CreateMeditationNarrations do
  use Ecto.Migration

  @moduledoc """
  One row per (meditation, voice) recording, so a meditation can be heard
  in more than one narration voice.

  Until now `meditations.audio_url` was the S3 key of the single narration,
  a root-level object in the audio bucket. From here on it is the
  meditation's audio *filename*, and each voice's object lives at
  `voices/<slug>/<filename>`. The backfill below records every existing
  narration as the `male` voice at its new key; the objects themselves are
  copied there by `LumenViae.Release.copy_narration_to_voice_prefix/0`,
  which must run against the bucket around the same time as this
  migration (before it, ideally - see docs/CSV_IMPORT_GUIDE.md).
  """

  def up do
    create table(:meditation_narrations) do
      add :meditation_id, references(:meditations, on_delete: :delete_all), null: false
      add :voice, :string, null: false
      add :s3_key, :string, null: false
      add :generated_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:meditation_narrations, [:meditation_id, :voice])
    create index(:meditation_narrations, [:voice])

    # Every narration that exists today was synthesized with the original
    # (male) voice. The generated_at is unknown, so the row's own timestamp
    # stands in for it.
    execute """
    INSERT INTO meditation_narrations (meditation_id, voice, s3_key, generated_at, inserted_at, updated_at)
    SELECT id, 'male', 'voices/male/' || audio_url, NOW(), NOW(), NOW()
    FROM meditations
    WHERE audio_url IS NOT NULL AND audio_url <> ''
    """
  end

  def down do
    drop table(:meditation_narrations)
  end
end
