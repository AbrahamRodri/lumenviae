defmodule LumenViae.Repo.Migrations.AddPrayerAudioFields do
  use Ecto.Migration

  def change do
    alter table(:mysteries) do
      add :announcement_audio_url, :string
      add :description_audio_url, :string
    end

    alter table(:meditations) do
      add :intro_audio_url, :string
    end
  end
end
