defmodule LumenViae.Rosary.Meditation.NoNarrationMarkup do
  @moduledoc """
  Keeps narration markup out of a meditation's content.

  Content is rendered verbatim (whitespace-pre-wrap), so the markup must
  never reach the database: `{pause:N}` markers are stripped by the CSV
  importer before the action runs, and break tags only ever exist in the
  text sent to ElevenLabs.

  Only content that is being written is checked, so a row that predates
  the rule can still have its other fields edited.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    with true <- Ash.Changeset.changing_attribute?(changeset, :content),
         content when is_binary(content) <- Ash.Changeset.get_attribute(changeset, :content),
         message when is_binary(message) <- markup_error(content) do
      {:error, field: :content, message: message}
    else
      _nothing_to_report -> :ok
    end
  end

  defp markup_error(content) do
    cond do
      content =~ ~r/<\s*break\b/i ->
        "must not contain <break> tags; narration pauses are added at audio generation"

      content =~ ~r/\{\s*pause\b/i ->
        "contains an unprocessed {pause:N} marker; markers are only supported in CSV imports, which strip them"

      true ->
        nil
    end
  end
end
