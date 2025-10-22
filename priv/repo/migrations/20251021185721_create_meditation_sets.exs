defmodule LumenViae.Repo.Migrations.CreateMeditationSets do
  use Ecto.Migration

  def change do
    create table(:meditation_sets) do
      add :name, :string, null: false
      add :category, :string, null: false
      add :description, :text

      timestamps()
    end

    create index(:meditation_sets, [:category])
  end
end
