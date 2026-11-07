defmodule LumenViae.Repo.Migrations.CloseStraySpacesBeforePunctuation do
  use Ecto.Migration

  # Some imported meditations (Sheen's Sorrowful set among them) carry a
  # space before a comma, semicolon, colon or full stop: "Our Lord ,
  # though guilty", "said to His enemies . Evil". The space is closed up,
  # and where the mark ran straight into the next word ("was come ,brought")
  # the space goes after it instead. An ellipsis (" ...") is left as
  # written.
  #
  # Text only: nothing is narrated again. A narration's timed lines match
  # the page's words without their punctuation, so the lit lines are
  # unchanged. A meditation with {pause:N} annotations is skipped, since
  # those hold character offsets into the text that a shorter text would
  # move. Running it twice changes nothing. The CSV importer closes the
  # same spaces from now on (LumenViae.Curation.CsvImport).
  # Each changed row's text as it was is kept first in
  # meditation_content_before_20261106 (not an Ash resource: a plain backup
  # table, read only by down/0), so a rollback puts back the exact old
  # text and updated_at. Drop the table once the change has stood.
  @where """
  content ~ '\\S +([,;:]|\\.(?!\\.))'
    AND (tts_annotations IS NULL OR cardinality(tts_annotations) = 0)
  """

  def up do
    execute """
    CREATE TABLE meditation_content_before_20261106 AS
    SELECT id, content, updated_at FROM meditations WHERE #{@where}
    """

    execute """
    UPDATE meditations
    SET content =
          regexp_replace(
            regexp_replace(content, '(\\S) +([,;:])(?=[[:alpha:]])', '\\1\\2 ', 'g'),
            '(\\S) +([,;:]|\\.(?!\\.))',
            '\\1\\2',
            'g'
          ),
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE id IN (SELECT id FROM meditation_content_before_20261106)
    """
  end

  def down do
    execute """
    UPDATE meditations m
    SET content = b.content, updated_at = b.updated_at
    FROM meditation_content_before_20261106 b
    WHERE m.id = b.id
    """

    execute "DROP TABLE meditation_content_before_20261106"
  end
end
