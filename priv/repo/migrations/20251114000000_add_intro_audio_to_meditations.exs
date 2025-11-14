defmodule LumenViae.Repo.Migrations.AddIntroAudioToMeditations do
  use Ecto.Migration

  def change do
    alter table(:meditations) do
      add :intro_audio_url, :string
    end
  end
end
