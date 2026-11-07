defmodule LumenViae.Repo.Migrations.CreditSheenGloriousSet do
  use Ecto.Migration

  # Set 25 (Sheen, the Glorious Mysteries) never had a byline of its own:
  # it showed the author and source its meditations agreed on. Since
  # 20261107020000 credits meditation 135 to G. K. Chesterton, whose poem
  # the booklet quotes, they no longer agree, and the set showed none. It is
  # given its own, as sets 26 and 27 have.
  #
  # Only an empty author or source is filled, so a value already there is
  # left as it is, and running it twice changes nothing. The set is kept
  # first, as it was, in meditation_set_byline_before_20261107 (a plain
  # backup table, read only by down/0), so a rollback puts back the exact old
  # values.

  @author "Archbishop Fulton J. Sheen"
  @booklet "The Meditations on the Fifteen Mysteries of the Rosary (Catechetical Guild, 1952)"

  def up do
    execute """
    CREATE TABLE meditation_set_byline_before_20261107 AS
    SELECT id, author, source, updated_at FROM meditation_sets WHERE id = 25
    """

    execute """
    UPDATE meditation_sets
    SET author = COALESCE(NULLIF(author, ''), #{sql(@author)}),
        source = COALESCE(NULLIF(source, ''), #{sql(@booklet)}),
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE id = 25
      AND (author IS NULL OR author = '' OR source IS NULL OR source = '')
    """
  end

  def down do
    execute """
    UPDATE meditation_sets s
    SET author = b.author, source = b.source, updated_at = b.updated_at
    FROM meditation_set_byline_before_20261107 b
    WHERE s.id = b.id
    """

    execute "DROP TABLE meditation_set_byline_before_20261107"
  end

  defp sql(text), do: "'" <> String.replace(text, "'", "''") <> "'"
end
