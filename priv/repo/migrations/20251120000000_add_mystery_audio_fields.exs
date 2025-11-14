defmodule LumenViae.Repo.Migrations.AddMysteryAudioFields do
  use Ecto.Migration

  def change do
    alter table(:mysteries) do
      add :announcement_audio_url, :text
      add :description_audio_url, :text
    end
  end
end
