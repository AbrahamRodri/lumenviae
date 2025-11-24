defmodule LumenViae.Repo.Migrations.CreateRosaryCompletions do
  use Ecto.Migration

  def change do
    create table(:rosary_completions) do
      add :meditation_set_id, references(:meditation_sets, on_delete: :delete_all), null: false
      add :completed_at, :utc_datetime, null: false

      timestamps(updated_at: false)
    end

    create index(:rosary_completions, [:meditation_set_id])
    create index(:rosary_completions, [:completed_at])
  end
end
