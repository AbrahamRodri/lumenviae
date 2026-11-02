defmodule LumenViae.Rosary.NarrationLinesDataTest do
  @moduledoc """
  The line timings the migrations load from `priv/narration_lines/`: each
  file only the recordings on its list, each with the recording it was
  measured on, and lines a player can follow - in order, never overlapping,
  and holding spoken words only, never a direction tag.

  - `female.json`: Arabella's 75 re-recorded meditations
    (`female_v3_meditations.csv`);
  - `frederick_meditative.json` and `female_meditative.json`: the 167
    meditative recordings of 2 Nov 2026, Frederick's 121 and Arabella's 46
    (`*_meditative_recordings.csv`).
  """
  use ExUnit.Case, async: true

  alias NimbleCSV.RFC4180, as: CSV

  @root Path.expand("../../../priv", __DIR__)

  @files [
    {"female.json", "female_v3_meditations.csv"},
    {"frederick_meditative.json", "frederick_meditative_recordings.csv"},
    {"female_meditative.json", "female_meditative_recordings.csv"}
  ]

  for {file, list} <- @files do
    describe file do
      setup do
        timings =
          Path.join([@root, "narration_lines", unquote(file)]) |> File.read!() |> Jason.decode!()

        [header | rows] =
          Path.join([@root, "narration_scripts", unquote(list)])
          |> File.read!()
          |> CSV.parse_string(skip_headers: false)

        id = Enum.find_index(header, &(&1 == "meditation_id"))
        audio = Enum.find_index(header, &(&1 == "audio_file"))
        recordings = Map.new(rows, &{Enum.at(&1, id), Enum.at(&1, audio)})

        %{timings: timings, recordings: recordings}
      end

      test "times only the listed recordings, each against its own file", %{
        timings: timings,
        recordings: recordings
      } do
        assert map_size(timings) > 0

        for {id, %{"audio_file" => file}} <- timings do
          assert Map.fetch!(recordings, id) == file, "#{id} names #{file}"
        end
      end

      test "every recording's lines run in order and never overlap", %{timings: timings} do
        for {id, %{"lines" => lines}} <- timings do
          assert lines != [], "#{id} has no lines"

          Enum.reduce(lines, 0.0, fn %{"text" => text, "start" => start, "end" => stop},
                                     previous ->
            assert is_binary(text) and text != "", "#{id} has an empty line"
            refute text =~ "[", "#{id} has a direction tag in #{inspect(text)}"
            assert start >= previous and stop > start, "#{id}: #{inspect(text)} is out of order"
            stop
          end)
        end
      end
    end
  end
end
