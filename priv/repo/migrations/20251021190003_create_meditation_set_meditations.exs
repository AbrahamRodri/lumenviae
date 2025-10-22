defmodule LumenViae.Repo.Migrations.CreateMeditationSetMeditations do
  use Ecto.Migration

  def change do
    create table(:meditation_set_meditations) do
      add :meditation_set_id, references(:meditation_sets, on_delete: :delete_all), null: false
      add :meditation_id, references(:meditations, on_delete: :delete_all), null: false
      add :order, :integer, null: false

      timestamps()
    end

    create index(:meditation_set_meditations, [:meditation_set_id])
    create index(:meditation_set_meditations, [:meditation_id])
    create unique_index(:meditation_set_meditations, [:meditation_set_id, :meditation_id])
    create unique_index(:meditation_set_meditations, [:meditation_set_id, :order])
  end
end
