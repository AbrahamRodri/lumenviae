defmodule LumenViae.Repo.Migrations.AddAnnouncementAudioToMysteries do
  use Ecto.Migration

  def change do
    alter table(:mysteries) do
      add :announcement_audio_url, :string
    end
  end
end
