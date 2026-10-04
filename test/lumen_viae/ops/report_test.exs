defmodule LumenViae.Ops.ReportTest do
  use ExUnit.Case, async: true

  alias LumenViae.Ops.Report

  test "queues line up in columns, one row per queue" do
    text =
      Report.queues([
        %{queue: "elevenlabs", limit: 1, counts: %{"available" => 12, "discarded" => 2}},
        %{queue: "geolocation", limit: nil, counts: %{}}
      ])

    [header, elevenlabs, geolocation] = String.split(text, "\n")
    assert header =~ ~r/^queue\s+limit\s+waiting/
    assert elevenlabs =~ ~r/^elevenlabs\s+1\s+12\s+0\s+0\s+0\s+2/
    assert geolocation =~ ~r/^geolocation\s+-\s+0/
  end

  test "failures say so when there are none" do
    assert Report.failures([]) == "Nothing has failed in the last seven days."
  end
end
