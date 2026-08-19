defmodule LumenViae.Repo.Migrations.AddAttributionToMeditationSets do
  use Ecto.Migration

  def change do
    alter table(:meditation_sets) do
      # A byline for the set itself, so the picker can show one before any
      # meditation is loaded. Optional: when it is absent the byline is
      # derived from the set's meditations, and only when they all agree.
      add :author, :string
      add :source, :text
    end
  end
end
