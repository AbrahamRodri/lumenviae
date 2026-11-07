defmodule LumenViae.Repo.Migrations.ProofreadSheenAndCorrectCredits do
  use Ecto.Migration

  # The proofread of 7 November 2026 (reports/rig/content-proof) and the
  # sources found for two sets of credits:
  #
  # - Sheen's sets (25 to 27) come from his booklet "The Meditations on the
  #   Fifteen Mysteries of the Rosary" (Catechetical Guild, 1952), not from a
  #   book called "The Fifteen Mysteries of the Rosary". Five fixes in their
  #   text: a dash the booklet prints (127), a stray comma, a double space
  #   and a nested quotation (122), a straight closing quote (126), a colon
  #   (125). Meditation 135 is G. K. Chesterton's "Regina Angelorum", which
  #   the booklet quotes with his name; it is credited to him, and a comma
  #   where the sentence runs on is put back.
  # - The "Let us contemplate in this mystery" texts of sets 28 to 30 are not
  #   in Liguori's Glories of Mary: they are the traditional method of the
  #   Rosary printed in many 19th-century prayer books. Their source and
  #   descriptions say so, and set 29's alt text spells Liguori right.
  #
  # Text only: nothing is narrated again. Every replacement is of exact
  # words, so a row already changed, or one that differs, is left as it is,
  # and running it twice changes nothing. A meditation with {pause:N}
  # annotations is skipped, since those hold character offsets into the
  # text. Every row touched is kept first, as it was, in
  # meditation_proofread_before_20261107 and
  # meditation_set_credits_before_20261107 (plain backup tables, read only
  # by down/0), so a rollback puts back the exact old text, credits and
  # updated_at. Drop them once the change has stood.

  @sheen_sets [25, 26, 27]
  @method_sets [28, 29, 30]

  @booklet "The Meditations on the Fifteen Mysteries of the Rosary (Catechetical Guild, 1952)"
  @method "Traditional method of the Rosary, from 19th-century Catholic prayer books"

  @method_descriptions %{
    "glorious" =>
      "A short reflection and prayer for each Glorious Mystery, from the traditional method of the Rosary printed in 19th-century Catholic prayer books.",
    "joyful" =>
      "A short reflection and prayer for each Joyful Mystery, from the traditional method of the Rosary printed in 19th-century Catholic prayer books.",
    "sorrowful" =>
      "A short reflection and prayer for each Sorrowful Mystery, from the traditional method of the Rosary printed in 19th-century Catholic prayer books."
  }

  # {meditation id, words as they are, words as they should be}
  @fixes [
    {127, "illumined by whose stripes", "illumined – by whose stripes"},
    {122, "the cousin, of His Mother", "the cousin of His Mother"},
    {122, "In the days that followed,  Mary", "In the days that followed, Mary"},
    {122,
     "voice, “Blessed art thou among women, and blessed is the fruit of thy womb” (Luke 1:39-42).",
     "voice, ‘Blessed art thou among women, and blessed is the fruit of thy womb.’” (Luke 1:39-42)."},
    {126, "and I found none.\"", "and I found none.”"},
    {125, "souls in the world; those", "souls in the world: those"},
    {135, "Tall as their toppling towns. \n", "Tall as their toppling towns, \n"}
  ]

  def up do
    execute """
    CREATE TABLE meditation_proofread_before_20261107 AS
    SELECT m.id, m.content, m.author, m.source, m.updated_at
    FROM meditations m
    WHERE m.id IN (
      SELECT j.meditation_id FROM meditation_set_meditations j
      WHERE j.meditation_set_id IN (#{ids(@sheen_sets ++ @method_sets)})
    )
    """

    execute """
    CREATE TABLE meditation_set_credits_before_20261107 AS
    SELECT id, source, description, image_alt, updated_at
    FROM meditation_sets
    WHERE id IN (#{ids(@sheen_sets ++ @method_sets)})
    """

    for {id, from, to} <- @fixes do
      execute """
      UPDATE meditations
      SET content = replace(content, #{sql(from)}, #{sql(to)}), #{now()}
      WHERE id = #{id}
        AND strpos(content, #{sql(from)}) > 0
        AND (tts_annotations IS NULL OR cardinality(tts_annotations) = 0)
      """
    end

    execute """
    UPDATE meditations
    SET author = 'G. K. Chesterton',
        source = 'Regina Angelorum, in The Queen of Seven Swords (1926)', #{now()}
    WHERE id = 135 AND source = 'The Fifteen Mysteries of the Rosary'
    """

    execute """
    UPDATE meditations
    SET source = #{sql(@booklet)}, #{now()}
    WHERE source = 'The Fifteen Mysteries of the Rosary'
      AND id IN (SELECT id FROM meditation_proofread_before_20261107)
    """

    execute """
    UPDATE meditations
    SET source = #{sql(@method)}, #{now()}
    WHERE source = 'Glories of Mary'
      AND id IN (
        SELECT j.meditation_id FROM meditation_set_meditations j
        WHERE j.meditation_set_id IN (#{ids(@method_sets)})
      )
    """

    execute """
    UPDATE meditation_sets
    SET source = #{sql(@booklet)}, #{now()}
    WHERE id IN (#{ids(@sheen_sets)}) AND source = 'The Fifteen Mysteries of the Rosary'
    """

    for {category, description} <- @method_descriptions do
      execute """
      UPDATE meditation_sets
      SET source = #{sql(@method)}, description = #{sql(description)}, #{now()}
      WHERE id IN (#{ids(@method_sets)}) AND category = #{sql(category)}
        AND (source IS NULL OR source IN ('', 'Glories of Mary'))
        AND description LIKE '%Glories of Mary%'
      """
    end

    execute """
    UPDATE meditation_sets
    SET image_alt = replace(image_alt, 'Ligouri', 'Liguori'), #{now()}
    WHERE id IN (#{ids(@method_sets)}) AND image_alt LIKE '%Ligouri%'
    """
  end

  def down do
    execute """
    UPDATE meditations m
    SET content = b.content, author = b.author, source = b.source, updated_at = b.updated_at
    FROM meditation_proofread_before_20261107 b
    WHERE m.id = b.id
    """

    execute """
    UPDATE meditation_sets s
    SET source = b.source, description = b.description, image_alt = b.image_alt,
        updated_at = b.updated_at
    FROM meditation_set_credits_before_20261107 b
    WHERE s.id = b.id
    """

    execute "DROP TABLE meditation_proofread_before_20261107"
    execute "DROP TABLE meditation_set_credits_before_20261107"
  end

  defp ids(list), do: Enum.join(list, ", ")
  defp now, do: "updated_at = date_trunc('second', timezone('UTC', now()))"
  defp sql(text), do: "'" <> String.replace(text, "'", "''") <> "'"
end
