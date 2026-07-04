defmodule LumenViae.Repo.Migrations.BackfillMeditationSetLabels do
  use Ecto.Migration

  # Editorial backfill so the whole catalog is labeled in one pass when the
  # labels feature deploys (the iOS picker shows filter chips as soon as any
  # set in a category is labeled, and unlabeled sets fall into a trailing
  # "More" section). Every update is guarded on labels = '{}' so labels
  # assigned through the admin UI are never overwritten, and sets with
  # unmatched names are simply left unlabeled.
  #
  # Bishop Fulton J. Sheen is Venerable, not canonized, so his sets are
  # Contemplative only while St. Alphonsus Liguori's also carry Saints.
  def up do
    execute """
    UPDATE meditation_sets SET labels = '{Contemplative}'
    WHERE labels = '{}' AND name LIKE '%Fulton J. Sheen%'
    """

    execute """
    UPDATE meditation_sets SET labels = '{Saints,Contemplative}'
    WHERE labels = '{}' AND name LIKE '%Alphonsus Liguori%'
    """

    execute """
    UPDATE meditation_sets SET labels = '{Intentions}'
    WHERE labels = '{}' AND name IN (
      'For Scrupulous Minds',
      'On Divine Providence',
      'On Dryness',
      'On Detachment',
      'On Purpose',
      'On Patience',
      'For those Married',
      'Marriage'
    )
    """

    execute """
    UPDATE meditation_sets SET labels = '{Scriptural}'
    WHERE labels = '{}' AND name = 'Scripture + Short Meditation'
    """

    execute """
    UPDATE meditation_sets SET labels = '{Contemplative}'
    WHERE labels = '{}' AND name = 'Meditation + Prayer'
    """
  end

  # Reverts only rows still carrying exactly the labels this migration set,
  # so labels changed through the admin UI afterwards survive a rollback.
  def down do
    execute """
    UPDATE meditation_sets SET labels = '{}'
    WHERE labels = '{Contemplative}'
      AND (name LIKE '%Fulton J. Sheen%' OR name = 'Meditation + Prayer')
    """

    execute """
    UPDATE meditation_sets SET labels = '{}'
    WHERE labels = '{Saints,Contemplative}' AND name LIKE '%Alphonsus Liguori%'
    """

    execute """
    UPDATE meditation_sets SET labels = '{}'
    WHERE labels = '{Intentions}' AND name IN (
      'For Scrupulous Minds',
      'On Divine Providence',
      'On Dryness',
      'On Detachment',
      'On Purpose',
      'On Patience',
      'For those Married',
      'Marriage'
    )
    """

    execute """
    UPDATE meditation_sets SET labels = '{}'
    WHERE labels = '{Scriptural}' AND name = 'Scripture + Short Meditation'
    """
  end
end
