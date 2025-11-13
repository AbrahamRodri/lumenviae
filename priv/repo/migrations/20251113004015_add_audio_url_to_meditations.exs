defmodule LumenViae.Repo.Migrations.AddAudioUrlToMeditations do
  use Ecto.Migration

  def change do
    alter table(:meditations) do
      add :audio_url, :text
    end
  end
end
