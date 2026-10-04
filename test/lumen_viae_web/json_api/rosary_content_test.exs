defmodule LumenViaeWeb.JsonApi.RosaryContentTest do
  @moduledoc """
  `GET /api/v2/rosary-content`: the Rosary's words as one document. The
  bare request is the version and the date, which is how a device asks
  whether its saved copy is current; the sections come when named in
  `fields[rosary_content]=`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary.Content

  # The strict form the app's ISO8601DateFormatter accepts: whole seconds, Z.
  @instant ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/

  test "the bare request carries the version and the date, and nothing else", %{conn: conn} do
    conn = get_v2(conn, "/rosary-content")
    body = v2_response(conn, 200)

    assert %{"type" => "rosary_content", "id" => "current", "attributes" => attributes} =
             body["data"]

    assert Map.keys(attributes) |> Enum.sort() == ["updated_at", "version"]
    assert attributes["version"] == Content.version()
    assert attributes["updated_at"] =~ @instant
    assert attributes["updated_at"] == DateTime.to_iso8601(Content.updated_at())

    assert get_resp_header(conn, "cache-control") == ["private, no-store"]
  end

  test "the version is the same on every request", %{conn: conn} do
    versions =
      for _ <- 1..3 do
        conn
        |> get_v2("/rosary-content")
        |> v2_response(200)
        |> get_in(["data", "attributes", "version"])
      end

    assert [version, version, version] = versions
  end

  test "the prayers come when asked for, all twelve, in the order they are said", %{conn: conn} do
    attributes =
      conn
      |> get_v2("/rosary-content?fields[rosary_content]=version,prayers")
      |> v2_response(200)
      |> get_in(["data", "attributes"])

    assert Map.keys(attributes) |> Enum.sort() == ["prayers", "version"]

    prayers = attributes["prayers"]

    assert Enum.map(prayers, & &1["id"]) == Content.prayer_ids()

    for prayer <- prayers do
      assert Map.keys(prayer) |> Enum.sort() == ~w(group id text title)
      assert length(prayer["text"]["en"]) == length(prayer["text"]["la"])
    end

    # Exactly the words the server holds, line for line.
    assert prayers == Content.prayers()
  end

  test "the Hail Mary, as a client reads it", %{conn: conn} do
    prayers =
      conn
      |> get_v2("/rosary-content?fields[rosary_content]=prayers")
      |> v2_response(200)
      |> get_in(["data", "attributes", "prayers"])

    assert %{
             "id" => "hail_mary",
             "group" => "rosary",
             "title" => %{"en" => "The Hail Mary", "la" => "Ave Maria"},
             "text" => %{
               "en" => ["Hail Mary, full of grace, the Lord is with thee;" | _],
               "la" => ["Ave Maria, gratia plena, Dominus tecum;" | _]
             }
           } = Enum.find(prayers, &(&1["id"] == "hail_mary"))
  end
end
