defmodule LumenViae.Repo.Migrations.AddLocationToRosaryCompletions do
  use Ecto.Migration

  def change do
    alter table(:rosary_completions) do
      add :ip_address, :string
      add :city, :string
      add :region, :string
      add :country, :string
      add :country_code, :string
    end
  end
end
