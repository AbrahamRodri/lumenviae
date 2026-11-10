defmodule LumenViae.Repo.Migrations.CreditLiguoriGloriesOfMary do
  use Ecto.Migration

  # Sets 28 to 30 (St. Alphonsus Liguori's Glorious, Joyful and Sorrowful
  # meditations) were credited on 7 Nov 2026 to "Traditional method of the
  # Rosary, from 19th-century Catholic prayer books", because the proofread
  # found their text in no complete Glories of Mary. It is in one: the 1902
  # Benziger popular edition, "Meditations for the Rosary", pp. 370-381
  # (archive.org gloriesofmary0000ligu_k0b6;
  # reports/rig/liguori-sets/evidence.md). Abraham, 10 Nov 2026, pick A:
  # credit that edition, keep St. Alphonsus's name and portrait.
  #
  # - The sets' and their meditations' source, and the sets' descriptions,
  #   name the 1902 edition. The rows are found by the 7 Nov credit, which
  #   only they carry, so no id is assumed.
  # - The Finding in the Temple takes the 1902 wording, the one place the
  #   text differed: "(through no fault of hers)" and "sitting in the midst
  #   of the doctors, hearing them and asking them questions". Its recording
  #   is not made again (no ElevenLabs): the lines from the changed one stay
  #   unlit, as for any edited meditation.
  #
  # Text only. Every row touched is kept first, as it was, in
  # meditation_glories_before_20261110 and
  # meditation_set_glories_before_20261110 (plain backup tables, read only
  # by down/0), and each change is of exact words, so a row that differs
  # is left as it is. Drop them once the change has stood.

  def up do
    execute """
    CREATE TABLE meditation_glories_before_20261110 AS
    SELECT id, content, source, updated_at
    FROM meditations
    WHERE source = 'Traditional method of the Rosary, from 19th-century Catholic prayer books'
    """

    execute """
    CREATE TABLE meditation_set_glories_before_20261110 AS
    SELECT id, source, description, updated_at
    FROM meditation_sets
    WHERE source = 'Traditional method of the Rosary, from 19th-century Catholic prayer books'
    """

    execute """
    UPDATE meditations
    SET content = replace(
          replace(content,
            'after having lost her beloved Son in Jerusalem',
            'after having lost (through no fault of hers) her beloved Son in Jerusalem'),
          'in the midst of the doctors, disputing with them, being of the age of twelve years',
          'sitting in the midst of the doctors, hearing them and asking them questions, being of the age of twelve years'),
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE id IN (SELECT id FROM meditation_glories_before_20261110)
      AND strpos(content, 'in the midst of the doctors, disputing with them, being of the age of twelve years') > 0
      AND strpos(content, 'after having lost her beloved Son in Jerusalem') > 0
      AND (tts_annotations IS NULL OR cardinality(tts_annotations) = 0)
    """

    execute """
    UPDATE meditations
    SET source = 'The Glories of Mary (Benziger, 1902), Meditations for the Rosary',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE id IN (SELECT id FROM meditation_glories_before_20261110)
    """

    execute """
    UPDATE meditation_sets
    SET source = 'The Glories of Mary (Benziger, 1902), Meditations for the Rosary',
        description = replace(description,
          'from the traditional method of the Rosary printed in 19th-century Catholic prayer books.',
          'from The Glories of Mary (Benziger, 1902), Meditations for the Rosary.'),
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE id IN (SELECT id FROM meditation_set_glories_before_20261110)
    """
  end

  def down do
    execute """
    UPDATE meditations m
    SET content = b.content, source = b.source, updated_at = b.updated_at
    FROM meditation_glories_before_20261110 b
    WHERE m.id = b.id
    """

    execute """
    UPDATE meditation_sets s
    SET source = b.source, description = b.description, updated_at = b.updated_at
    FROM meditation_set_glories_before_20261110 b
    WHERE s.id = b.id
    """

    execute "DROP TABLE meditation_glories_before_20261110"
    execute "DROP TABLE meditation_set_glories_before_20261110"
  end
end
