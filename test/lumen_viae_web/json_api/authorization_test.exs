defmodule LumenViaeWeb.JsonApi.AuthorizationTest do
  @moduledoc """
  `/api/v2` is anonymous. It is served off the browser pipeline, with no
  session and no CSRF token, so it never reads the console's cookie: every
  request runs with no actor and gets exactly what the public may, through
  the same actions and policies as GraphQL. The one write is the public
  completion; nothing else can be written through it, signed in or not,
  and no query parameter widens what a read returns.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary

  defp hidden_set(category \\ "joyful") do
    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "Empty #{System.unique_integer([:positive])}", category: category},
        actor: admin()
      )

    set
  end

  defp visible_set(category \\ "joyful") do
    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "Shown #{System.unique_integer([:positive])}", category: category},
        actor: admin()
      )

    LumenViae.Test.Sets.with_meditation(set)
  end

  test "the only routes that write are the completion and the audio refresh, which writes nothing" do
    routes =
      LumenViaeWeb.JsonApiRouter
      |> AshJsonApi.Router.formatted_routes()
      |> Enum.reject(&(&1.verb == :get))
      |> Enum.map(&{&1.verb, &1.path})
      |> Enum.sort()

    assert routes == [{:post, "/completions"}, {:post, "/meditations/audio"}]
  end

  test "a write the API does not offer is not routed", %{conn: conn} do
    set = visible_set()

    for {verb, path} <- [
          {:patch, "/api/v2/meditation-sets/#{set.id}"},
          {:delete, "/api/v2/meditation-sets/#{set.id}"},
          {:post, "/api/v2/meditation-sets"},
          {:post, "/api/v2/mysteries"}
        ] do
      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> dispatch(@endpoint, verb, path, ~s({"data": {"attributes": {"name": "Renamed"}}}))

      assert conn.status == 404
    end

    assert Rosary.get_meditation_set!(set.id, actor: admin()).name == set.name
  end

  test "an admin's session cookie does not make /api/v2 an admin", %{conn: conn} do
    set = hidden_set()

    # The set exists, and an admin outside the API does see it.
    assert {:ok, _} = Rosary.get_meditation_set(set.id, actor: admin())

    as_admin = conn |> log_in_admin() |> get_v2("/meditation-sets/#{set.id}")
    as_public = build_conn() |> get_v2("/meditation-sets/#{set.id}")

    assert as_admin.status == 404
    assert as_public.status == 404

    strip_ids = fn conn ->
      conn |> v2_response(404) |> update_in(["errors", Access.all()], &Map.delete(&1, "id"))
    end

    # Exactly the anonymous answer, with nothing that would tell them apart.
    assert strip_ids.(as_admin) == strip_ids.(as_public)

    listed =
      conn
      |> log_in_admin()
      |> get_v2("/meditation-sets?category=joyful")
      |> v2_response(200)
      |> Map.fetch!("data")
      |> Enum.map(& &1["id"])

    refute to_string(set.id) in listed
  end

  # The actions declare their own filter and order, and the API offers no
  # other: a filter, sort or page parameter is ignored, not applied.
  test "a filter, sort or page cannot widen, narrow or reorder a read", %{conn: conn} do
    shown = visible_set("glorious")
    hidden = hidden_set("glorious")
    _later = visible_set("glorious")

    plain = conn |> get_v2("/meditation-sets?category=glorious") |> v2_response(200)
    assert to_string(shown.id) in Enum.map(plain["data"], & &1["id"])

    for query <- [
          "filter[name]=#{URI.encode_www_form(hidden.name)}",
          "filter[id]=#{hidden.id}",
          "filter[id]=#{shown.id}",
          "sort=-name",
          "sort=-id",
          "page[limit]=1"
        ] do
      body =
        build_conn()
        |> get_v2("/meditation-sets?category=glorious&" <> query)
        |> v2_response(200)

      assert body["data"] == plain["data"], "#{query} changed the answer"
    end
  end

  test "a private field cannot be asked for", %{conn: conn} do
    set = visible_set()

    for query <- [
          "fields[meditation_set]=author_id",
          "fields[meditation_set]=meditations",
          "fields[meditation_set]=author_profile",
          "fields[meditation_set]=completions",
          "include=set_memberships.meditation&fields[meditation]=audio_url",
          "include=set_memberships.meditation&fields[meditation]=archived_at",
          "include=set_memberships.meditation&fields[meditation]=tts_annotations",
          "include=set_memberships.meditation&fields[meditation]=narration"
        ] do
      body = conn |> get_v2("/meditation-sets/#{set.id}?" <> query) |> v2_response(400)
      assert [%{"code" => "invalid_field"} | _] = body["errors"]
    end
  end

  test "only the prayer-order path can be included", %{conn: conn} do
    set = visible_set()

    for include <- [
          "meditations",
          "author_profile",
          "completions",
          "set_memberships.meditation_set",
          "set_memberships.meditation.narrations",
          "set_memberships.meditation.meditation_sets"
        ] do
      body =
        conn |> get_v2("/meditation-sets/#{set.id}?include=#{include}") |> v2_response(400)

      assert [%{"code" => "invalid_includes"} | _] = body["errors"]
    end
  end

  # The content document is the same for everyone: nothing in the query
  # string can change what it serves, and it has nothing to include.
  test "the content document takes no include, and no filter or sort changes it", %{conn: conn} do
    plain = conn |> get_v2("/rosary-content?fields[rosary_content]=prayers") |> v2_response(200)

    for query <- ["filter[id]=other", "sort=-version", "page[limit]=1"] do
      body =
        build_conn()
        |> get_v2("/rosary-content?fields[rosary_content]=prayers&" <> query)
        |> v2_response(200)

      assert body["data"] == plain["data"], "#{query} changed the answer"
    end

    body = build_conn() |> get_v2("/rosary-content?include=prayers") |> v2_response(400)
    assert [%{"code" => "invalid_includes"} | _] = body["errors"]

    body =
      build_conn() |> get_v2("/rosary-content?fields[rosary_content]=secret") |> v2_response(400)

    assert [%{"code" => "invalid_field"} | _] = body["errors"]
  end

  test "an archived meditation never arrives through an included path", %{conn: conn} do
    set = visible_set()
    [meditation] = Rosary.get_meditation_set!(set.id, actor: admin()).meditations
    {:ok, _} = Rosary.archive_meditation(meditation, actor: admin())

    conn
    |> get_v2("/meditation-sets/#{set.id}?include=set_memberships.meditation")
    |> v2_response(404)
  end
end
