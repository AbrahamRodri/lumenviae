defmodule LumenViae.Repo.Migrations.TimeArabellaMeditativeLines do
  @moduledoc """
  Stores the line timings measured on Arabella's 75 meditations re-recorded
  on 2 Nov 2026 (`priv/narration_lines/female.json`, made by
  `scripts/narration_lines.py` from those recordings).

  Data only, and only those rows: each update names the meditation, the
  voice and the exact S3 key the timings were measured on, so a row that
  has since been recorded again keeps no stale timings and nothing else is
  touched. Running it twice writes the same values. `down` clears the
  lines of the same rows.
  """
  use Ecto.Migration

  def up do
    for {meditation_id, voice, s3_key, lines} <- timings() do
      repo().query!(
        "UPDATE meditation_narrations SET lines = $1 WHERE meditation_id = $2 AND voice = $3 AND s3_key = $4",
        [lines, meditation_id, voice, s3_key]
      )
    end
  end

  def down do
    for {meditation_id, voice, s3_key, _lines} <- timings() do
      repo().query!(
        "UPDATE meditation_narrations SET lines = NULL WHERE meditation_id = $1 AND voice = $2 AND s3_key = $3",
        [meditation_id, voice, s3_key]
      )
    end
  end

  defp timings do
    :lumen_viae
    |> Application.app_dir("priv/narration_lines/female.json")
    |> File.read!()
    |> Jason.decode!()
    |> Enum.map(fn {id, %{"audio_file" => file, "lines" => lines}} ->
      {String.to_integer(id), "female", "voices/female/" <> file, lines}
    end)
  end
end
