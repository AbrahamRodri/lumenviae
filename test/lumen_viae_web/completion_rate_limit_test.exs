defmodule LumenViaeWeb.CompletionRateLimitTest do
  @moduledoc """
  The completion limit lives on the `Completion` actions
  (`LumenViae.Rosary.Completion.RateLimit`), so every way of recording a
  Rosary - `POST /api/completions`, the Complete button on the prayer page and
  GraphQL's `recordCompletion` - spends one budget per address and trips at
  the same count. These tests drive all three, each as a client does, rather
  than the action, so a surface that stopped passing the address or started
  limiting on its own would show here.

  What each surface answers is pinned by its own tests
  (`API.CompletionGuardTest`, `Graphql.RecordCompletionTest`); what is pinned
  here is that the three agree.

  Not async: the limit is read from the application environment, which this
  file lowers, and the counters are global. Every test spends its own address.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]
  import LumenViaeWeb.GraphqlHelpers
  import Phoenix.LiveViewTest

  alias LumenViae.Limits
  alias LumenViae.Rosary
  alias LumenViae.Test.Sets

  @limit 2
  @browser "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Version/17.2 Safari/605.1.15"
  @surfaces [:rest, :page, :graphql]

  @mutation """
  mutation Record($input: RecordCompletionInput!) {
    recordCompletion(input: $input) {
      result { id }
      errors { code message }
    }
  }
  """

  setup do
    put_env(:lumen_viae, :completions_per_hour, @limit)

    {:ok, set} =
      Rosary.create_meditation_set(%{name: "Limited", category: "joyful"}, actor: admin())

    Sets.with_meditation(set)

    n = System.unique_integer([:positive])
    ip = "198.51.#{rem(n, 200)}.#{rem(div(n, 200), 200)}"

    conn =
      build_conn()
      |> Plug.Conn.put_req_header("fly-client-ip", ip)
      |> Plug.Conn.put_req_header("user-agent", @browser)

    %{set: set, conn: conn, ip: ip}
  end

  # Each surface records one completion and says what happened to it:
  # `:recorded`, or `{:refused, answer}` with the surface's own answer.
  defp complete(:rest, conn, set) do
    conn = post(conn, ~p"/api/completions", %{meditation_set_id: set.id})

    case conn.status do
      201 -> :recorded
      429 -> {:refused, json_response(conn, 429)}
    end
  end

  # The page answers the same either way, by design: it sends the reader
  # back to the category. Whether anything was recorded is read from the
  # table.
  defp complete(:page, conn, set) do
    before = Rosary.count_total_completions(actor: admin())

    press_complete(conn, set)

    if Rosary.count_total_completions(actor: admin()) > before,
      do: :recorded,
      else: {:refused, nil}
  end

  defp complete(:graphql, conn, set) do
    body =
      graphql(conn, @mutation, %{input: %{meditationSetId: to_string(set.id)}})

    case body do
      %{"data" => %{"recordCompletion" => %{"result" => %{"id" => _}}}} -> :recorded
      %{"errors" => [%{"code" => "rate_limited"}]} = refused -> {:refused, refused}
    end
  end

  # The set has one meditation, so its last mystery, where the Complete
  # button is offered, is the first.
  defp press_complete(conn, set) do
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=0")

    view |> element("button[phx-click=complete]") |> render_click()
  end

  for refused <- @surfaces do
    test "the budget is spent on the other two surfaces and refused on #{refused}",
         %{conn: conn, set: set} do
      spenders = Enum.reject(@surfaces, &(&1 == unquote(refused)))

      # The budget is spent a surface at a time, round robin, so no one
      # surface is the only one counting.
      for n <- 0..(@limit - 1) do
        surface = Enum.at(spenders, rem(n, length(spenders)))
        assert complete(surface, conn, set) == :recorded
      end

      before = Rosary.count_total_completions(actor: admin())

      assert {:refused, _answer} = complete(unquote(refused), conn, set)
      assert Rosary.count_total_completions(actor: admin()) == before
    end
  end

  test "all three surfaces allow exactly the limit and then refuse", %{conn: conn, set: set} do
    for surface <- @surfaces do
      conn =
        conn
        |> Plug.Conn.put_req_header("fly-client-ip", "203.0.113.#{:erlang.phash2(surface, 200)}")

      for _ <- 1..@limit, do: assert(complete(surface, conn, set) == :recorded)
      assert {:refused, _} = complete(surface, conn, set)
      assert {:refused, _} = complete(surface, conn, set)
    end
  end

  describe "what each surface says" do
    test "REST answers 429 with the envelope it has always sent", %{conn: conn, set: set} do
      for _ <- 1..@limit, do: assert(complete(:rest, conn, set) == :recorded)

      assert {:refused, body} = complete(:rest, conn, set)

      assert body == %{
               "error" => %{
                 "code" => "rate_limited",
                 "message" => "Too many completions from this address"
               }
             }
    end

    test "GraphQL answers a top-level error and no data", %{conn: conn, set: set} do
      for _ <- 1..@limit, do: assert(complete(:graphql, conn, set) == :recorded)

      assert {:refused, body} = complete(:graphql, conn, set)

      assert body["data"] == nil

      assert [%{"code" => "rate_limited", "message" => "Too many completions from this address"}] =
               body["errors"]
    end

    test "the prayer page still sends the reader back to the category", %{conn: conn, set: set} do
      for _ <- 1..@limit, do: assert(complete(:rest, conn, set) == :recorded)

      assert {:error, {:live_redirect, %{to: "/mysteries/joyful"}}} = press_complete(conn, set)
    end
  end

  describe "what spends the budget" do
    test "a refused request is still counted, so hammering stays blocked", %{conn: conn, set: set} do
      for _ <- 1..@limit, do: assert(complete(:rest, conn, set) == :recorded)

      for _ <- 1..5, do: assert({:refused, _} = complete(:rest, conn, set))
    end

    test "a crawler is turned away before it can spend any", %{conn: conn, set: set} do
      crawler = Plug.Conn.put_req_header(conn, "user-agent", "Googlebot/2.1")

      for _ <- 1..(@limit + 2) do
        assert crawler
               |> post(~p"/api/completions", %{meditation_set_id: set.id})
               |> json_response(403)
      end

      for _ <- 1..@limit, do: assert(complete(:rest, conn, set) == :recorded)
    end

    test "a set that does not exist spends it like any other", %{conn: conn, set: set} do
      for _ <- 1..@limit do
        body = graphql(conn, @mutation, %{input: %{meditationSetId: "0"}})
        assert %{"errors" => [%{"code" => "invalid_argument"}]} = body["data"]["recordCompletion"]
      end

      assert {:refused, _} = complete(:graphql, conn, set)
      assert {:refused, _} = complete(:rest, conn, set)
    end

    test "reads are not counted", %{conn: conn, set: set} do
      for _ <- 1..(@limit + 3) do
        get(conn, ~p"/api/meditation-sets")
        graphql(conn, "{ voices { slug } }")
      end

      for _ <- 1..@limit, do: assert(complete(:graphql, conn, set) == :recorded)
    end
  end

  describe "the action" do
    test "returns the limit in a Forbidden error, for a caller to turn into its own answer",
         %{set: set, ip: ip} do
      for _ <- 1..@limit, do: assert({:ok, _} = Rosary.record_completion(set.id, %{ip: ip}))

      assert {:error, %Ash.Error.Forbidden{} = error} =
               Rosary.record_completion(set.id, %{ip: ip})

      assert %AshRateLimiter.LimitExceeded{limit: @limit} = Limits.exceeded(error)
    end

    test "does not limit a caller with no address", %{set: set} do
      for _ <- 1..(@limit + 3), do: assert({:ok, _} = Rosary.record_completion(set.id, %{}))
    end

    test "limits one address and not another", %{set: set, ip: ip} do
      for _ <- 1..@limit, do: assert({:ok, _} = Rosary.record_completion(set.id, %{ip: ip}))

      assert {:error, _} = Rosary.record_completion(set.id, %{ip: ip})
      assert {:ok, _} = Rosary.record_completion(set.id, %{ip: ip <> "1"})
    end

    test "keys on the full address, not the prefix that is stored", %{set: set} do
      n = System.unique_integer([:positive])
      neighbour = fn host -> "2001:db8:#{n}::#{host}" end

      for _ <- 1..@limit,
          do: assert({:ok, _} = Rosary.record_completion(set.id, %{ip: neighbour.(1)}))

      assert {:error, _} = Rosary.record_completion(set.id, %{ip: neighbour.(1)})
      assert {:ok, _} = Rosary.record_completion(set.id, %{ip: neighbour.(2)})
    end

    test "reads the limit from the environment when it runs", %{set: set, ip: ip} do
      put_env(:lumen_viae, :completions_per_hour, 1)

      assert {:ok, _} = Rosary.record_completion(set.id, %{ip: ip})
      assert {:error, _} = Rosary.record_completion(set.id, %{ip: ip})
    end
  end
end
