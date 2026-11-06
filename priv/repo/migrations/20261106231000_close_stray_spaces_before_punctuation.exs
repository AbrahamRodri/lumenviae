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
  def up do
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
    WHERE content ~ '\\S +([,;:]|\\.(?!\\.))'
      AND (tts_annotations IS NULL OR cardinality(tts_annotations) = 0)
    """
  end

  # The spaces were mistakes; there is nothing to put back.
  def down, do: :ok
end
