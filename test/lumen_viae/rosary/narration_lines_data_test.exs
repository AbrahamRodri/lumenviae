defmodule LumenViae.Rosary.NarrationLinesDataTest do
  @moduledoc """
  The line timings the migration loads (`priv/narration_lines/female.json`):
  only Arabella's 75 re-recorded meditations, each with the recording it was
  measured on, and lines a player can follow - in order, never overlapping,
  and holding spoken words only, never a direction tag.
  """
  use ExUnit.Case, async: true

  @file_path Path.expand("../../../priv/narration_lines/female.json", __DIR__)
  @list_path Path.expand("../../../priv/narration_scripts/female_v3_meditations.csv", __DIR__)

  setup_all do
    timings = @file_path |> File.read!() |> Jason.decode!()

    recordings =
      @list_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> tl()
      |> Map.new(fn row ->
        [id, _set, _name, _category, file | _] = String.split(row, ",")
        {id, file}
      end)

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

      Enum.reduce(lines, 0.0, fn %{"text" => text, "start" => start, "end" => stop}, previous ->
        assert is_binary(text) and text != "", "#{id} has an empty line"
        refute text =~ "[", "#{id} has a direction tag in #{inspect(text)}"
        assert start >= previous and stop > start, "#{id}: #{inspect(text)} is out of order"
        stop
      end)
    end
  end
end
