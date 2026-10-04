defmodule LumenViaeWeb.Graphql.RecordCompletionTest do
  @moduledoc """
  `recordCompletion`, the GraphQL twin of `POST /api/completions` and the
  one write the GraphQL API exposes: what it records, what it refuses, and
  the guard in front of it.

  Not async, and every test from its own address: the rate limit is a
  global counter keyed on address, and this file lowers it.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Repo
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completion
  alias LumenViae.Test.Addresses

  @limit 2

  @mutation """
  mutation Record($input: RecordCompletionInput!) {
    recordCompletion(input: $input) {
      result { id meditationSetId completedAt }
      errors { code message fields }
    }
  }
  """

  setup do
    previous = Application.get_env(:lumen_viae, :completions_per_hour)
    Application.put_env(:lumen_viae, :completions_per_hour, @limit)
    on_exit(fn -> Application.put_env(:lumen_viae, :completions_per_hour, previous) end)

    {:ok, set} =
      Rosary.create_meditation_set(%{name: "Prayed over GraphQL", category: "joyful"},
        actor: admin()
      )

    LumenViae.Test.Sets.with_meditation(set)

    %{set: set, conn: from_a_new_address(build_conn())}
  end

  defp from_a_new_address(conn) do
    put_req_header(conn, "fly-client-ip", Addresses.unique_ip())
  end

  defp as(conn, agent), do: put_req_header(conn, "user-agent", agent)

  defp record(conn, set_id, extra \\ %{}) do
    graphql(conn, @mutation, %{input: Map.merge(%{meditationSetId: to_string(set_id)}, extra)})
  end

  test "records a completion from the app, and answers as REST does", %{conn: conn, set: set} do
    body = record(conn, set.id, %{prayedAloud: true})
    refute Map.has_key?(body, "errors")
    %{"data" => %{"recordCompletion" => %{"result" => result, "errors" => []}}} = body

    assert result["meditationSetId"] == to_string(set.id)
    # Both ids are digits, so a client can store them as integers.
    assert result["id"] =~ ~r/^\d+$/
    assert result["meditationSetId"] =~ ~r/^\d+$/
    assert result["completedAt"] =~ ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/

    stored = Repo.get!(Completion, String.to_integer(result["id"]))
    assert stored.meditation_set_id == set.id
    assert stored.source == "ios"
    assert stored.prayed_aloud == true
    # The address is truncated before it is stored, never kept whole.
    assert stored.ip_prefix =~ ~r/^100\.\d+\.\d+\.0$/
  end

  test "a hidden set is refused exactly like a missing one", %{conn: conn, set: set} do
    {:ok, mystery} =
      Rosary.create_mystery(%{name: "Hidden", category: "joyful", order: 900_001}, actor: admin())

    {:ok, archived} =
      Rosary.create_meditation(%{content: "Withdrawn", mystery_id: mystery.id}, actor: admin())

    {:ok, _} = Rosary.add_meditation_to_set(set.id, archived.id, 2, actor: admin())
    {:ok, _} = Rosary.archive_meditation(archived, actor: admin())

    # A set with no meditations yet is hidden too.
    {:ok, empty} =
      Rosary.create_meditation_set(%{name: "Not filled yet", category: "joyful"}, actor: admin())

    hidden = record(conn, set.id)
    missing = record(conn, 999_999_999)
    # From another address: this test's budget per address is two.
    unfilled = record(from_a_new_address(build_conn()), empty.id)

    # A validation failure is answered in the mutation's own errors, beside
    # a null result, with a code; nothing at the top level.
    refute Map.has_key?(hidden, "errors")
    %{"result" => nil, "errors" => [hidden_error]} = hidden["data"]["recordCompletion"]
    %{"result" => nil, "errors" => [unfilled_error]} = unfilled["data"]["recordCompletion"]
    %{"result" => nil, "errors" => [missing_error]} = missing["data"]["recordCompletion"]

    assert %{"code" => "invalid_argument", "fields" => ["meditationSetId"]} = hidden_error
    assert hidden_error == missing_error
    assert unfilled_error == missing_error
  end

  test "a client cannot choose the source or its address", %{conn: conn, set: set} do
    body = record(conn, set.id, %{source: "web", ipPrefix: "10.0.0.0"})

    assert body["data"] == nil
    assert body["errors"] != []
  end

  describe "which app" do
    # Each from an address of its own: this file's budget is two an address.
    defp source_as(agent, set) do
      conn = from_a_new_address(build_conn())
      conn = if agent, do: as(conn, agent), else: conn

      %{"data" => %{"recordCompletion" => %{"result" => %{"id" => id}}}} = record(conn, set.id)
      Repo.get!(Completion, String.to_integer(id)).source
    end

    test "the Android app's agent records an Android completion", %{set: set} do
      for agent <- [
            "LumenViae-Android/1.0.0 (Android 14; Pixel 8)",
            "Dalvik/2.1.0 (Linux; U; Android 14; Pixel 8 Build/AP2A.240805.005)"
          ] do
        assert source_as(agent, set) == "android", agent
      end
    end

    test "the iOS app's agents, and no agent at all, record an iOS completion", %{set: set} do
      for agent <- [
            "app/5 CFNetwork/3826.500.111 Darwin/25.0.0",
            "app/4 CFNetwork/1568.100.1 Darwin/24.0.0",
            nil
          ] do
        assert source_as(agent, set) == "ios", inspect(agent)
      end
    end
  end

  describe "the guard" do
    test "turns a crawler away, and records nothing", %{conn: conn, set: set} do
      before = Rosary.count_total_completions(actor: admin())

      body =
        conn
        |> as("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")
        |> record(set.id)

      assert [%{"code" => "automated_client"}] = body["errors"]
      assert Rosary.count_total_completions(actor: admin()) == before
    end

    test "lets the app's own user agent through", %{conn: conn, set: set} do
      body = conn |> as("app/5 CFNetwork/3826.500.111 Darwin/25.0.0") |> record(set.id)

      assert %{"result" => %{"id" => _}} = body["data"]["recordCompletion"]
    end

    test "rate limits each address", %{conn: conn, set: set} do
      for _ <- 1..@limit do
        assert %{"result" => %{"id" => _}} = record(conn, set.id)["data"]["recordCompletion"]
      end

      body = record(conn, set.id)
      assert [%{"code" => "rate_limited"}] = body["errors"]
    end

    test "shares one budget with POST /api/completions", %{conn: conn, set: set} do
      for _ <- 1..@limit do
        conn
        |> post("/api/completions", %{meditation_set_id: set.id})
        |> json_response(201)
      end

      assert [%{"code" => "rate_limited"}] = record(conn, set.id)["errors"]
    end

    test "is not spent by reads", %{conn: conn, set: set} do
      for _ <- 1..(@limit + 3), do: graphql(conn, "{ voices { slug } }")

      assert %{"result" => %{"id" => _}} = record(conn, set.id)["data"]["recordCompletion"]
    end
  end
end
