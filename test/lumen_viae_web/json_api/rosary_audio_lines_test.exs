defmodule LumenViaeWeb.JsonApi.RosaryAudioLinesTest do
  @moduledoc """
  Each spoken-Rosary clip's `lines` (`LumenViae.Rosary.PrayerAudio.lines/2`)
  on `GET /api/v2/rosary-audio`, GraphQL's `rosaryAudio` and the v1
  `GET /api/rosary/audio`: the same lines on all three, null for a clip
  not timed. The rest of each clip is as before.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]
  import LumenViaeWeb.GraphqlHelpers
  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary.{PrayerAudio, Voices}
  alias LumenViae.Test.SpokenRosaryClips

  # The lines are production's recordings, keyed by file names that hash
  # production's voices; the suite runs on voices of its own.
  setup do
    put_env(:ex_aws, :access_key_id, "test-key")
    put_env(:ex_aws, :secret_access_key, "test-secret")
    put_env(:lumen_viae, :narration_voices, SpokenRosaryClips.production_voices())
    :ok
  end

  # What a client is served for a clip: the lines with string keys, or nil.
  defp expected(clip) do
    case PrayerAudio.lines(Voices.default(), clip) do
      nil -> nil
      lines -> Enum.map(lines, &%{"text" => &1.text, "start" => &1.start, "end" => &1.end})
    end
  end

  defp by_name(clips), do: Map.new(clips, &{&1.name, &1})

  test "v1: every clip carries its lines, or null", %{conn: conn} do
    data =
      conn
      |> get("/api/rosary/audio?include=prayers,announcements,verses,book")
      |> json_response(200)
      |> Map.fetch!("data")

    prayers = by_name(PrayerAudio.prayers())
    book = by_name(PrayerAudio.book())

    for {id, clip} <- data["prayers"], do: assert(clip["lines"] == expected(prayers[id]), id)
    for {id, clip} <- data["book"], do: assert(clip["lines"] == expected(book[id]), id)

    for announcement <- PrayerAudio.announcements() do
      assert data["announcements"][announcement.mystery]["lines"] == expected(announcement)
    end

    for verse <- PrayerAudio.verses() do
      served = Enum.at(data["verses"][verse.mystery], verse.bead - 1)
      assert served["lines"] == expected(verse)
    end

    assert [%{"text" => "Hail Mary, full of grace, the Lord is with thee;"} | _] =
             data["prayers"]["hail_mary"]["lines"]
  end

  test "v2 and GraphQL serve the same lines as v1", %{conn: conn} do
    rest =
      conn
      |> get("/api/rosary/audio?include=prayers,announcements,verses,book")
      |> json_response(200)
      |> Map.fetch!("data")

    pack =
      conn
      |> get_v2("/rosary-audio?fields[spoken_rosary]=prayers,announcements,verses,book")
      |> v2_response(200)
      |> get_in(["data", "attributes"])

    assert Map.new(pack["prayers"], &{&1["id"], &1["lines"]}) ==
             Map.new(rest["prayers"], fn {id, clip} -> {id, clip["lines"]} end)

    assert Map.new(pack["announcements"], &{&1["key"], &1["lines"]}) ==
             Map.new(rest["announcements"], fn {key, clip} -> {key, clip["lines"]} end)

    assert Map.new(pack["verses"], &{&1["key"], Enum.map(&1["clips"], fn c -> c["lines"] end)}) ==
             Map.new(rest["verses"], fn {key, clips} -> {key, Enum.map(clips, & &1["lines"])} end)

    %{"data" => %{"rosaryAudio" => graph}} =
      graphql(build_conn(), """
      { rosaryAudio { prayers { id lines { text start end } } } }
      """)

    assert Map.new(graph["prayers"], &{&1["id"], &1["lines"]}) ==
             Map.new(rest["prayers"], fn {id, clip} -> {id, clip["lines"]} end)
  end
end
