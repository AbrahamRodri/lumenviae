defmodule LumenViaeWeb.JsonApi.OpenApiTest do
  @moduledoc """
  What the versioned API exposes, pinned.

  The OpenAPI document is the contract a generated client is built from,
  so the whole of it is committed in `priv/openapi/v2.json` and must match
  the running one exactly: any change to what `/api/v2` exposes is a diff
  in that file, in review, rather than a quiet side effect of editing a
  resource. Regenerate it with:

      mix openapi.spec.json --spec LumenViaeWeb.JsonApiRouter --pretty=true --vendor-extensions=false --start-app=false priv/openapi/v2.json

  And the columns that must never reach a client are named outright, so a
  regenerated document cannot wave one through.
  """
  use LumenViaeWeb.ConnCase, async: true

  @snapshot "priv/openapi/v2.json"

  # Field names that would leak something private: S3 keys instead of
  # signed URLs, the analytics' network prefix and place, moderation
  # state, raw artwork columns that bypass the publishable gate, narration
  # markup, the meditation's audio filename, the raw links between
  # records, a stale schedule and a config ordinal. The last three are
  # Ash's names for fields served under the GraphQL names (narrations,
  # author, source); seeing them would mean the renaming was lost. (A
  # completion's source is decided by the server; the input test below
  # pins that.)
  @never_exposed ~w(
    s3_key ip_prefix city region country country_code time_zone locale
    archived_at image_key image_alt image_license image_focal_x image_focal_y
    tts_annotations audio_url author_id mystery_id days_prayed position
    signed_narrations byline_author byline_source
  )

  # Types a client must never reach.
  @never_reachable ~w(narration author admin token)

  # Every operation the API offers.
  @operations [
    {"get", "/api/v2/meditation-sets", "listMeditationSets"},
    {"get", "/api/v2/meditation-sets/{id}", "getMeditationSet"},
    {"get", "/api/v2/mysteries", "listMysteries"},
    {"get", "/api/v2/rosary-audio", "getRosaryAudio"},
    {"get", "/api/v2/rosary-content", "getRosaryContent"},
    {"get", "/api/v2/voices", "listVoices"},
    {"get", "/api/v2/voices/retired", "listRetiredVoices"},
    {"post", "/api/v2/completions", "recordCompletion"},
    {"post", "/api/v2/meditations/audio", "getMeditationAudio"}
  ]

  defp encoded do
    {:ok, json} =
      LumenViaeWeb.JsonApiRouter.spec()
      |> OpenApiSpex.OpenApi.to_map(vendor_extensions: false)
      |> OpenApiSpex.OpenApi.json_encoder().encode(pretty: true)

    json <> "\n"
  end

  defp document, do: Jason.decode!(encoded())

  defp schemas, do: document()["components"]["schemas"]

  # Every field of every resource, as a client sees it.
  defp fields do
    for {_type, %{"properties" => properties}} <- schemas(),
        section <- ["attributes", "relationships"],
        %{"properties" => fields} <- [properties[section]],
        name <- Map.keys(fields),
        uniq: true,
        do: name
  end

  test "the running document matches the committed snapshot" do
    assert encoded() == File.read!(@snapshot), """
    The OpenAPI document changed. If that is intended, regenerate the
    snapshot and review the diff as a change to the public API:

        mix openapi.spec.json --spec LumenViaeWeb.JsonApiRouter --pretty=true --vendor-extensions=false --start-app=false #{@snapshot}
    """
  end

  test "the document served is the committed file, byte for byte", %{conn: conn} do
    conn = get(conn, "/api/v2/open_api")

    assert conn.status == 200
    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "application/json"
    assert get_resp_header(conn, "cache-control") == ["public, max-age=3600"]
    assert conn.resp_body == File.read!(@snapshot)
  end

  # Swagger UI loads its script from a CDN, so it is served in development
  # only, like GraphiQL; the test environment has no dev routes.
  test "no page runs Swagger UI outside development", %{conn: conn} do
    for path <- ["/api/v2/docs", "/dev/api-docs"] do
      assert conn |> recycle() |> get(path) |> Map.fetch!(:status) == 404
    end
  end

  test "the list of sets offers no include, and nothing it could include" do
    operation = document()["paths"]["/api/v2/meditation-sets"]["get"]

    refute "include" in Enum.map(operation["parameters"], & &1["name"])

    body =
      operation["responses"]["200"]["content"]["application/vnd.api+json"]["schema"]

    refute Map.has_key?(body["properties"], "included")
  end

  test "offers exactly the operations it should" do
    operations =
      for {path, item} <- document()["paths"],
          {verb, %{"operationId" => id}} <- item,
          do: {verb, path, id}

    assert Enum.sort(operations) == Enum.sort(@operations)
  end

  test "no private column is a field of any resource" do
    leaked = Enum.filter(@never_exposed, &(&1 in fields()))
    assert leaked == [], "private fields exposed over /api/v2: #{inspect(leaked)}"
  end

  test "no private resource is a reachable type" do
    reachable = Enum.filter(@never_reachable, &Map.has_key?(schemas(), &1))
    assert reachable == [], "private resources reachable over /api/v2: #{inspect(reachable)}"
  end

  test "a completion shows exactly what the REST response shows" do
    attributes = schemas()["completion"]["properties"]["attributes"]["properties"]

    assert Enum.sort(Map.keys(attributes)) == ["completed_at", "meditation_set_id"]
    assert schemas()["completion"]["properties"]["relationships"]["properties"] == %{}
  end

  test "recording a completion takes the set and whether it was prayed aloud, nothing else" do
    body =
      document()["paths"]["/api/v2/completions"]["post"]["requestBody"]["content"][
        "application/vnd.api+json"
      ]["schema"]

    inputs = body["properties"]["data"]["properties"]["attributes"]["properties"]

    assert Enum.sort(Map.keys(inputs)) == ["meditation_set_id", "prayed_aloud"]
  end

  test "claims no authentication the API does not have" do
    assert document()["security"] in [nil, []]
    refute Map.has_key?(document()["components"], "securitySchemes")
  end
end
