defmodule LumenViae.ReleaseSummaryTest do
  @moduledoc """
  `LumenViae.Release.summary/0`: the dashboard's headline numbers as JSON
  lines for an agent, counts only, nothing per row.
  """
  use LumenViae.DataCase, async: false

  import ExUnit.CaptureIO

  alias LumenViae.Release
  alias LumenViae.Rosary

  test "prints the completion, library and queue counts as JSON lines, and no row" do
    {:ok, set} =
      Rosary.create_meditation_set(%{name: "Summary Set", category: "joyful"}, actor: admin())

    {:ok, _} = Rosary.record_completion(set.id, %{source: "web", prayed_aloud: true})

    output = capture_io(fn -> assert Release.summary() == :ok end)
    lines = output |> String.split("\n", trim: true) |> Enum.map(&Jason.decode!/1)
    by_section = Enum.group_by(lines, & &1["section"])

    assert [%{"commit" => _, "version" => _}] = by_section["release"]
    assert [%{"total" => 1, "today" => 1, "last_7" => 1}] = by_section["completions"]

    assert [%{"total" => 1, "sources" => %{"web" => 1}, "prayed_aloud" => %{"true" => 1}}] =
             by_section["completions_30_days"]

    assert [%{"meditation_sets" => sets}] = by_section["library"]
    assert sets >= 1
    assert Map.has_key?(by_section, "queue")

    refute output =~ "Summary Set"
    refute output =~ "ip_prefix"
  end
end
