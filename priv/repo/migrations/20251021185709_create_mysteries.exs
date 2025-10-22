defmodule LumenViae.Repo.Migrations.CreateMysteries do
  use Ecto.Migration

  def change do
    create table(:mysteries) do
      add :name, :string, null: false
      add :category, :string, null: false
      add :order, :integer, null: false
      add :days_prayed, :string
      add :description, :text
      add :scripture_reference, :text

      timestamps()
    end

    create index(:mysteries, [:category])
    create unique_index(:mysteries, [:category, :order])
  end
end
