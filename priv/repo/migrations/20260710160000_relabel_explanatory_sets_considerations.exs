defmodule LumenViae.Repo.Migrations.RelabelExplanatorySetsConsiderations do
  use Ecto.Migration

  # The labels backfill marked every author set "Contemplative", but the
  # vocabulary now splits meditation style in two: "Contemplative" is
  # reserved for imaginative, scene-based prayer in the Ignatian sense
  # (Emmerich's visions), while "Considerations" covers discursive
  # explanation of the mystery's meaning in the classical manual sense
  # (Sheen's essays, Liguori's "Consider how..." points). Relabel the
  # explanatory sets; Emmerich's sets keep "Contemplative".
  #
  # Every update is guarded on the exact labels the backfill wrote, so
  # labels changed through the admin UI since then are never overwritten.
  def up do
    execute """
    UPDATE meditation_sets SET labels = '{Considerations}'
    WHERE labels = '{Contemplative}' AND name LIKE '%Fulton J. Sheen%'
    """

    execute """
    UPDATE meditation_sets SET labels = '{Saints,Considerations}'
    WHERE labels = '{Saints,Contemplative}' AND name LIKE '%Alphonsus Liguori%'
    """
  end

  def down do
    execute """
    UPDATE meditation_sets SET labels = '{Contemplative}'
    WHERE labels = '{Considerations}' AND name LIKE '%Fulton J. Sheen%'
    """

    execute """
    UPDATE meditation_sets SET labels = '{Saints,Contemplative}'
    WHERE labels = '{Saints,Considerations}' AND name LIKE '%Alphonsus Liguori%'
    """
  end
end
