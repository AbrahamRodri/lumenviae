defmodule LumenViae.Repo.Migrations.AddPrayedAloudToRosaryCompletions do
  use Ecto.Migration

  @moduledoc """
  Whether a finished Rosary was prayed with the spoken Rosary on - the app
  (or the site) saying every prayer aloud - or read silently.

  Nullable, and deliberately so: every row written before this, and every
  completion from a build that does not send it, genuinely does not know,
  and `false` would claim those Rosaries were prayed silently.
  """

  def change do
    alter table(:rosary_completions) do
      add :prayed_aloud, :boolean
    end
  end
end
