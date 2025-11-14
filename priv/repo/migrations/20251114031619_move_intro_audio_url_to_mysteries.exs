defmodule LumenViae.Repo.Migrations.MoveIntroAudioUrlToMysteries do
  use Ecto.Migration

  def change do
    # Add intro_audio_url to mysteries table
    alter table(:mysteries) do
      add :intro_audio_url, :string
    end

    # Remove intro_audio_url from meditations table
    alter table(:meditations) do
      remove :intro_audio_url
    end
  end
end
