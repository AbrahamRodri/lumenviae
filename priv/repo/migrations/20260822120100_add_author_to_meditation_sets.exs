defmodule LumenViae.Repo.Migrations.AddAuthorToMeditationSets do
  use Ecto.Migration

  def change do
    alter table(:meditation_sets) do
      # Deleting an author must not delete or hide their sets; the sets just
      # lose the linked record and fall back to their own artwork and byline.
      add :author_id, references(:authors, on_delete: :nilify_all)
    end

    create index(:meditation_sets, [:author_id])
  end
end
