defmodule LumenViae.Repo.Migrations.AddArchivedAtToMeditations do
  use Ecto.Migration

  def change do
    alter table(:meditations) do
      add :archived_at, :utc_datetime
    end
  end
end
