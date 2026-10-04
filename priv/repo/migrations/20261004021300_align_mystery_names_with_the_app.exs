defmodule LumenViae.Repo.Migrations.AlignMysteryNamesWithTheApp do
  use Ecto.Migration

  # Six mysteries were named in production otherwise than the iOS app
  # names them, so the website, a meditation's mystery in the API and the
  # announcement the spoken Rosary says read differently. They take the
  # app's names (MysteryData.swift), which PrayerAudio's announcements
  # already use.
  #
  # Each rename is guarded on the exact old name, as production holds it
  # (the snapshot of 19 August 2026, confirmed against the live API on 3
  # October), so a name a curator has changed since is never overwritten,
  # and running it twice changes nothing. A CSV import's mystery_name must
  # match the new names from now on (docs/CSV_IMPORT_GUIDE.md).
  def up do
    execute """
    UPDATE mysteries SET name = 'The Coronation', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'glorious' AND "order" = 5 AND name = 'The Coronation of Mary'
    """

    execute """
    UPDATE mysteries SET name = 'The Baptism in the Jordan', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'luminous' AND "order" = 1 AND name = 'The Baptism of Jesus'
    """

    execute """
    UPDATE mysteries SET name = 'Mary Meets Jesus Carrying the Cross', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 4 AND name = 'Mary Meets Jesus on the Way to Calvary'
    """

    execute """
    UPDATE mysteries SET name = 'The Crucifixion', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 5 AND name = 'Jesus Dies on the Cross'
    """

    execute """
    UPDATE mysteries SET name = 'Jesus Taken Down from the Cross', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 6 AND name = 'Mary Receives the Dead Body of Jesus in Her Arms'
    """

    execute """
    UPDATE mysteries SET name = 'The Burial of Jesus', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 7 AND name = 'Jesus is Placed in the Tomb'
    """
  end

  # Restores only names still exactly as this migration left them.
  def down do
    execute """
    UPDATE mysteries SET name = 'The Coronation of Mary'
    WHERE category = 'glorious' AND "order" = 5 AND name = 'The Coronation'
    """

    execute """
    UPDATE mysteries SET name = 'The Baptism of Jesus'
    WHERE category = 'luminous' AND "order" = 1 AND name = 'The Baptism in the Jordan'
    """

    execute """
    UPDATE mysteries SET name = 'Mary Meets Jesus on the Way to Calvary'
    WHERE category = 'seven_sorrows' AND "order" = 4 AND name = 'Mary Meets Jesus Carrying the Cross'
    """

    execute """
    UPDATE mysteries SET name = 'Jesus Dies on the Cross'
    WHERE category = 'seven_sorrows' AND "order" = 5 AND name = 'The Crucifixion'
    """

    execute """
    UPDATE mysteries SET name = 'Mary Receives the Dead Body of Jesus in Her Arms'
    WHERE category = 'seven_sorrows' AND "order" = 6 AND name = 'Jesus Taken Down from the Cross'
    """

    execute """
    UPDATE mysteries SET name = 'Jesus is Placed in the Tomb'
    WHERE category = 'seven_sorrows' AND "order" = 7 AND name = 'The Burial of Jesus'
    """
  end
end
