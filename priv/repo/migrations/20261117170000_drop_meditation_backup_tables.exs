defmodule LumenViae.Repo.Migrations.DropMeditationBackupTables do
  use Ecto.Migration

  # The text and credit changes of 6 to 10 Nov 2026 each kept the rows they
  # changed in a plain backup table (not an Ash resource), read only by that
  # migration's down/0, so the change could be rolled back. Each has stood
  # for a week with no problem reported, so the copies go. The meditations
  # and sets themselves are untouched.
  #
  # Not reversible: the copies' rows are gone. down/0 does nothing, and the
  # down/0 of those earlier migrations can no longer put old text back.
  @tables ~w(
    meditation_content_before_20261106
    meditation_proofread_before_20261107
    meditation_set_credits_before_20261107
    meditation_set_byline_before_20261107
    meditation_glories_before_20261110
    meditation_set_glories_before_20261110
  )

  def up do
    for table <- @tables, do: execute("DROP TABLE IF EXISTS #{table}")
  end

  def down, do: :ok
end
