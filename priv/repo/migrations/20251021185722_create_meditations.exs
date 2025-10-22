defmodule LumenViae.Repo.Migrations.CreateMeditations do
  use Ecto.Migration

  def change do
    create table(:meditations) do
      add :title, :string
      add :content, :text, null: false
      add :author, :string
      add :source, :string
      add :mystery_id, references(:mysteries, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:meditations, [:mystery_id])
    create index(:meditations, [:author])
  end
end
