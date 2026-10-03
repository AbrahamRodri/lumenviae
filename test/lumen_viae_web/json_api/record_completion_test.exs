defmodule LumenViaeWeb.JsonApi.RecordCompletionTest do
  @moduledoc """
  `POST /api/v2/completions`, the one write the versioned API exposes. It
  runs `Completion`'s `:record_from_app`, the action GraphQL's
  `recordCompletion` runs, so it records what that records and refuses
  what that refuses: the server stamps the moment, the source and the
  truncated address, a hidden set is refused like a missing one, and a
  crawler is refused by the action itself, since this route has no guard
  plug.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Repo
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completion

  setup do
    {:ok, set} =
      Rosary.create_meditation_set(%{name: "Prayed over v2", category: "joyful"}, actor: admin())

    LumenViae.Test.Sets.with_meditation(set)

    %{set: set, conn: from_a_new_address(build_conn())}
  end

  defp from_a_new_address(conn) do
    n = System.unique_integer([:positive])
    put_req_header(conn, "fly-client-ip", "203.0.#{rem(n, 200)}.#{rem(div(n, 200), 200)}")
  end

  defp record(conn, attributes) do
    post_v2(conn, "/completions", %{data: %{type: "completion", attributes: attributes}})
  end

  test "records a completion from the app, and answers with what REST answers", %{
    conn: conn,
    set: set
  } do
    body = conn |> record(%{meditation_set_id: set.id, prayed_aloud: true}) |> v2_response(201)

    assert %{"type" => "completion", "id" => id, "attributes" => attributes} = body["data"]
    assert id =~ ~r/^\d+$/
    assert Map.keys(attributes) |> Enum.sort() == ["completed_at", "meditation_set_id"]
    assert attributes["meditation_set_id"] == set.id
    assert attributes["completed_at"] =~ ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/

    stored = Repo.get!(Completion, String.to_integer(id))
    assert stored.meditation_set_id == set.id
    assert stored.source == "ios"
    assert stored.prayed_aloud == true
    # The address comes from the connection and is truncated before it is
    # stored, never kept whole.
    assert stored.ip_prefix =~ ~r/^203\.0\.\d+\.0$/
  end

  test "a hidden set is refused exactly like a missing one", %{conn: conn, set: set} do
    {:ok, mystery} =
      Rosary.create_mystery(%{name: "Hidden v2", category: "joyful", order: 900_002},
        actor: admin()
      )

    {:ok, archived} =
      Rosary.create_meditation(%{content: "Withdrawn", mystery_id: mystery.id}, actor: admin())

    {:ok, _} = Rosary.add_meditation_to_set(set.id, archived.id, 2, actor: admin())
    {:ok, _} = Rosary.archive_meditation(archived, actor: admin())

    {:ok, empty} =
      Rosary.create_meditation_set(%{name: "Not filled yet", category: "joyful"}, actor: admin())

    before = Rosary.count_total_completions(actor: admin())

    [hidden, unfilled, missing] =
      for id <- [set.id, empty.id, 999_999_999] do
        [error] =
          conn |> record(%{meditation_set_id: id}) |> v2_response(400) |> Map.fetch!("errors")

        Map.delete(error, "id")
      end

    assert %{
             "code" => "invalid_argument",
             "source" => %{"pointer" => "/data/attributes/meditation_set_id"}
           } = missing

    assert hidden == missing
    assert unfilled == missing
    assert Rosary.count_total_completions(actor: admin()) == before
  end

  test "a client cannot choose the source, its address or the moment", %{conn: conn, set: set} do
    before = Rosary.count_total_completions(actor: admin())

    for extra <- [
          %{source: "web"},
          %{ip_prefix: "10.0.0.0"},
          %{completed_at: "2001-01-01T00:00:00Z"},
          %{city: "Rome"}
        ] do
      conn
      |> record(Map.merge(%{meditation_set_id: set.id}, extra))
      |> v2_response(400)
    end

    assert Rosary.count_total_completions(actor: admin()) == before
  end

  describe "a crawler" do
    defp as(conn, agent), do: put_req_header(conn, "user-agent", agent)

    test "is refused with REST's 403, and records nothing", %{conn: conn, set: set} do
      before = Rosary.count_total_completions(actor: admin())

      for agent <- [
            "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
            "curl/8.7.1",
            "python-requests/2.32.3"
          ] do
        body =
          conn
          |> as(agent)
          |> record(%{meditation_set_id: set.id})
          |> v2_response(403)

        assert [
                 %{
                   "status" => "403",
                   "code" => "automated_client",
                   "detail" => "Automated clients cannot record completions"
                 }
               ] = body["errors"]
      end

      assert Rosary.count_total_completions(actor: admin()) == before
    end

    test "is told apart from the app and from a browser", %{conn: conn, set: set} do
      for agent <- [
            "app/5 CFNetwork/3826.500.111 Darwin/25.0.0",
            "Lumen%20Viae/3 CFNetwork/1568.100.1 Darwin/24.0.0",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " <>
              "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            "Mozilla/5.0 (Linux; Android 10; Cubot X30) AppleWebKit/537.36 " <>
              "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"
          ] do
        conn
        |> as(agent)
        |> record(%{meditation_set_id: set.id})
        |> v2_response(201)
      end
    end

    test "is decided by the request's agent, not by anything in the body", %{
      conn: conn,
      set: set
    } do
      conn
      |> as("app/5 CFNetwork/3826.500.111 Darwin/25.0.0")
      |> record(%{meditation_set_id: set.id, user_agent: "Googlebot/2.1"})
      |> v2_response(400)
    end
  end

  describe "the rate limit" do
    @limit 2

    setup do
      previous = Application.get_env(:lumen_viae, :completions_per_hour)
      Application.put_env(:lumen_viae, :completions_per_hour, @limit)
      on_exit(fn -> Application.put_env(:lumen_viae, :completions_per_hour, previous) end)
      :ok
    end

    defp rest(conn, set), do: post(conn, "/api/completions", %{meditation_set_id: set.id})

    defp graphql_record(conn, set) do
      LumenViaeWeb.GraphqlHelpers.graphql(
        conn,
        "mutation($id: ID!) { recordCompletion(input: {meditationSetId: $id}) { result { id } } }",
        %{id: to_string(set.id)}
      )
    end

    test "refuses an address over its budget with REST's 429", %{conn: conn, set: set} do
      for _ <- 1..@limit do
        conn |> record(%{meditation_set_id: set.id}) |> v2_response(201)
      end

      before = Rosary.count_total_completions(actor: admin())
      body = conn |> record(%{meditation_set_id: set.id}) |> v2_response(429)

      assert [
               %{
                 "status" => "429",
                 "code" => "rate_limited",
                 "detail" => "Too many completions from this address"
               }
             ] = body["errors"]

      assert Rosary.count_total_completions(actor: admin()) == before
    end

    test "spends one budget with REST and GraphQL", %{conn: conn, set: set} do
      conn |> rest(set) |> json_response(201)

      assert %{"data" => %{"recordCompletion" => %{"result" => %{"id" => _}}}} =
               graphql_record(conn, set)

      conn |> record(%{meditation_set_id: set.id}) |> v2_response(429)

      # And the other way round, from an address of its own.
      other = from_a_new_address(build_conn())

      for _ <- 1..@limit do
        other |> record(%{meditation_set_id: set.id}) |> v2_response(201)
      end

      assert %{"error" => %{"code" => "rate_limited"}} = other |> rest(set) |> json_response(429)
      assert [%{"code" => "rate_limited"}] = graphql_record(other, set)["errors"]
    end

    test "is not spent by a crawler, or by reads", %{conn: conn, set: set} do
      crawler = put_req_header(conn, "user-agent", "Googlebot/2.1")

      for _ <- 1..(@limit + 2) do
        crawler |> record(%{meditation_set_id: set.id}) |> v2_response(403)
        conn |> get_v2("/meditation-sets/#{set.id}") |> v2_response(200)
      end

      conn |> record(%{meditation_set_id: set.id}) |> v2_response(201)
    end
  end
end
