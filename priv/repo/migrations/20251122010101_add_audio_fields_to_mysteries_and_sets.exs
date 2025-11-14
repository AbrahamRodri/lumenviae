defmodule LumenViae.Repo.Migrations.AddAudioFieldsToMysteriesAndSets do
  use Ecto.Migration

  def change do
    alter table(:mysteries) do
      add :announcement_audio_url, :string
      add :description_audio_url, :string
    end

    alter table(:meditation_sets) do
      add :intro_audio_url, :string
    end
  end
end
