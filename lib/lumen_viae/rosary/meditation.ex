defmodule LumenViae.Rosary.Meditation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meditations" do
    field :title, :string
    field :content, :string
    field :author, :string
    field :source, :string
    field :audio_url, :string
    field :archived_at, :utc_datetime

    # Narration pause positions extracted from {pause:N} markers at import
    # time (see LumenViae.Audio.TtsText); consumed only when generating
    # ElevenLabs audio, never rendered.
    field :tts_annotations, {:array, :map}, default: []

    belongs_to :mystery, LumenViae.Rosary.Mystery

    many_to_many :meditation_sets, LumenViae.Rosary.MeditationSet,
      join_through: LumenViae.Rosary.MeditationSetMeditation

    timestamps()
  end

  @doc false
  # archived_at is intentionally not castable here; archiving goes through
  # Rosary.archive_meditation/1 so imports and forms cannot flip it.
  def changeset(meditation, attrs) do
    meditation
    |> cast(attrs, [:title, :content, :author, :source, :mystery_id, :audio_url, :tts_annotations])
    |> validate_required([:content, :mystery_id])
    |> validate_content_free_of_tts_markup()
    |> reset_stale_tts_annotations()
  end

  # Content is rendered verbatim (whitespace-pre-wrap), so narration markup
  # must never reach the database: {pause:N} markers are stripped by the CSV
  # importer before the changeset, and break tags only ever exist in the
  # text sent to ElevenLabs.
  defp validate_content_free_of_tts_markup(changeset) do
    validate_change(changeset, :content, fn :content, content ->
      cond do
        content =~ ~r/<\s*break\b/i ->
          [
            content:
              "must not contain <break> tags; narration pauses are added at audio generation"
          ]

        content =~ ~r/\{\s*pause\b/i ->
          [
            content:
              "contains an unprocessed {pause:N} marker; markers are only supported in CSV imports, which strip them"
          ]

        true ->
          []
      end
    end)
  end

  # Annotation offsets index into the content they were extracted from, so
  # they cannot survive a content edit that arrives without fresh ones.
  defp reset_stale_tts_annotations(changeset) do
    if get_change(changeset, :content) != nil and get_change(changeset, :tts_annotations) == nil do
      put_change(changeset, :tts_annotations, [])
    else
      changeset
    end
  end

  def archived?(%__MODULE__{archived_at: archived_at}), do: not is_nil(archived_at)
end
