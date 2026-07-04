defmodule LumenViae.Repo.Migrations.AddLabelsToMeditationSets do
  use Ecto.Migration

  def change do
    alter table(:meditation_sets) do
      add :labels, {:array, :string}, null: false, default: []
    end
  end
end
