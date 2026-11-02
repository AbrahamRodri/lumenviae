defmodule LumenViae.Repo.Migrations.TimeMeditativeLinesFrederickAndArabella do
  @moduledoc """
  Stores the line timings measured on the 167 meditative recordings made
  on 2 Nov 2026: Frederick's 121 (`priv/narration_lines/frederick_meditative.json`)
  and Arabella's 46 (`priv/narration_lines/female_meditative.json`), both
  made by `scripts/narration_lines.py` from those recordings.

  Data only, and only those rows: each update names the meditation, the
  voice and the exact S3 key the timings were measured on, so a row that
  has since been recorded again keeps no stale timings and nothing else is
  touched. Running it twice writes the same values. `down` clears the
  lines of the same rows.
  """
  use Ecto.Migration

  @files [{"frederick", "frederick_meditative.json"}, {"female", "female_meditative.json"}]

  # Unlogged: each statement carries a whole meditation's text.
  def up do
    for {meditation_id, voice, s3_key, lines} <- timings() do
      repo().query!(
        "UPDATE meditation_narrations SET lines = $1 WHERE meditation_id = $2 AND voice = $3 AND s3_key = $4",
        [lines, meditation_id, voice, s3_key],
        log: false
      )
    end
  end

  def down do
    for {meditation_id, voice, s3_key, _lines} <- timings() do
      repo().query!(
        "UPDATE meditation_narrations SET lines = NULL WHERE meditation_id = $1 AND voice = $2 AND s3_key = $3",
        [meditation_id, voice, s3_key],
        log: false
      )
    end
  end

  defp timings do
    for {voice, file} <- @files,
        {id, %{"audio_file" => audio_file, "lines" => lines}} <- read(file) do
      {String.to_integer(id), voice, "voices/#{voice}/" <> audio_file, lines}
    end
  end

  defp read(file) do
    :lumen_viae
    |> Application.app_dir("priv/narration_lines/" <> file)
    |> File.read!()
    |> Jason.decode!()
  end
end
