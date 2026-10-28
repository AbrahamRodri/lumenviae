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
  file lowers, and the counters are global. Every test spends an address of its
  own, from `LumenViae.Test.Addresses`: the counters outlive the test, so an
  address that anything else has used is already partly spent.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]
  import LumenViaeWeb.GraphqlHelpers
  import LumenViaeWeb.JsonApiHelpers, only: [post_v2: 3]
  import Phoenix.LiveViewTest

  alias LumenViae.Limits
  alias LumenViae.Rosary
  alias LumenViae.Test.Addresses
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

    ip = Addresses.unique_ip()

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

  # The Complete button is offered on the closing prayers.
  defp press_complete(conn, set) do
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=closing")

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
      conn = Plug.Conn.put_req_header(conn, "fly-client-ip", Addresses.unique_ip())

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

    test "the prayer page still shows the Rosary offered", %{conn: conn, set: set} do
      for _ <- 1..@limit, do: assert(complete(:rest, conn, set) == :recorded)

      assert press_complete(conn, set) =~ "The Rosary is offered"
    end
  end

  describe "an IPv6 caller" do
    test "spends one budget across the addresses of its /64, over every surface",
         %{conn: conn, set: set} do
      network = Addresses.unique_ipv6_network()

      from = fn host ->
        Plug.Conn.put_req_header(conn, "fly-client-ip", network <> "::" <> host)
      end

      # One address each time, as a phone with privacy extensions presents.
      assert complete(:rest, from.("1"), set) == :recorded
      assert complete(:graphql, from.("2"), set) == :recorded

      assert {:refused, _} = complete(:rest, from.("3"), set)
      assert {:refused, _} = complete(:graphql, from.("4"), set)
      assert {:refused, _} = complete(:page, from.("5"), set)
    end

    test "does not hold up another network", %{conn: conn, set: set} do
      one = Addresses.unique_ipv6_network()
      other = Addresses.unique_ipv6_network()
      from = fn network -> Plug.Conn.put_req_header(conn, "fly-client-ip", network <> "::1") end

      for _ <- 1..@limit, do: assert(complete(:rest, from.(one), set) == :recorded)

      assert {:refused, _} = complete(:rest, from.(one), set)
      assert complete(:rest, from.(other), set) == :recorded
    end
  end

  describe "Retry-After" do
    defp retry_after(conn) do
      assert [value] = Plug.Conn.get_resp_header(conn, "retry-after")
      assert {seconds, ""} = Integer.parse(value)
      seconds
    end

    defp rest_conn(conn, set), do: post(conn, ~p"/api/completions", %{meditation_set_id: set.id})

    defp v2_conn(conn, set) do
      post_v2(conn, "/completions", %{
        data: %{type: "completion", attributes: %{meditation_set_id: set.id}}
      })
    end

    test "says, on REST's 429, how long is left in the hour", %{conn: conn, set: set} do
      for _ <- 1..@limit, do: assert(rest_conn(conn, set).status == 201)

      refused = rest_conn(conn, set)

      assert refused.status == 429
      assert retry_after(refused) in 1..3_600
    end

    test "says it on /api/v2's 429 too", %{conn: conn, set: set} do
      for _ <- 1..@limit, do: assert(v2_conn(conn, set).status == 201)

      refused = v2_conn(conn, set)

      assert refused.status == 429
      assert retry_after(refused) in 1..3_600
    end

    test "is the same time on both, and no more than the window", %{conn: conn, set: set} do
      for _ <- 1..@limit, do: assert(rest_conn(conn, set).status == 201)

      rest = retry_after(rest_conn(conn, set))
      v2 = retry_after(v2_conn(conn, set))

      # They are read a moment apart, from one clock, so they agree to the
      # second, or are one second apart across a boundary.
      assert abs(rest - v2) <= 1
    end

    test "is not sent with a success", %{conn: conn, set: set} do
      assert Plug.Conn.get_resp_header(rest_conn(conn, set), "retry-after") == []

      assert Plug.Conn.get_resp_header(
               v2_conn(
                 Plug.Conn.put_req_header(conn, "fly-client-ip", Addresses.unique_ip()),
                 set
               ),
               "retry-after"
             ) ==
               []
    end

    test "keeps REST's 429 body exactly as it was", %{conn: conn, set: set} do
      for _ <- 1..@limit, do: assert(rest_conn(conn, set).status == 201)

      assert json_response(rest_conn(conn, set), 429) == %{
               "error" => %{
                 "code" => "rate_limited",
                 "message" => "Too many completions from this address"
               }
             }
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
      assert {:ok, _} = Rosary.record_completion(set.id, %{ip: Addresses.unique_ip()})
    end

    test "two addresses in one IPv6 /64 share a budget", %{set: set} do
      network = Addresses.unique_ipv6_network()

      # A subscriber with privacy extensions uses a new address in its /64
      # for each connection. Each one used to get a fresh budget.
      for host <- 1..@limit do
        assert {:ok, _} =
                 Rosary.record_completion(set.id, %{ip: network <> "::" <> to_string(host)})
      end

      assert {:error, %Ash.Error.Forbidden{} = error} =
               Rosary.record_completion(set.id, %{ip: network <> ":abcd:1234:5678:9abc"})

      assert %AshRateLimiter.LimitExceeded{} = Limits.exceeded(error)
    end

    test "two different IPv6 /64s do not", %{set: set} do
      one = Addresses.unique_ipv6_network()
      other = Addresses.unique_ipv6_network()

      for _ <- 1..@limit,
          do: assert({:ok, _} = Rosary.record_completion(set.id, %{ip: one <> "::1"}))

      assert {:error, _} = Rosary.record_completion(set.id, %{ip: one <> "::1"})
      assert {:ok, _} = Rosary.record_completion(set.id, %{ip: other <> "::1"})
    end

    test "spells an IPv6 address any way and counts one network", %{set: set} do
      network = Addresses.unique_ipv6_network()
      [a, b, c, d] = String.split(network, ":")

      short = "#{a}:#{b}:#{c}:#{d}::1"
      long = "#{a}:#{b}:#{c}:#{d}:0:0:0:1"
      upper = String.upcase("#{a}:#{b}:#{c}:#{d}:0000:0000:0000:0001")

      assert {:ok, _} = Rosary.record_completion(set.id, %{ip: short})
      assert {:ok, _} = Rosary.record_completion(set.id, %{ip: long})
      assert {:error, _} = Rosary.record_completion(set.id, %{ip: upper})
    end

    test "counts an IPv4-mapped IPv6 address as the IPv4 address it carries", %{set: set} do
      [a, b, c, d] = Addresses.unique_ip() |> String.split(".")

      for _ <- 1..@limit,
          do:
            assert(
              {:ok, _} = Rosary.record_completion(set.id, %{ip: "::ffff:#{a}.#{b}.#{c}.#{d}"})
            )

      assert {:error, _} = Rosary.record_completion(set.id, %{ip: "#{a}.#{b}.#{c}.#{d}"})
    end

    test "reads the limit from the environment when it runs", %{set: set, ip: ip} do
      put_env(:lumen_viae, :completions_per_hour, 1)

      assert {:ok, _} = Rosary.record_completion(set.id, %{ip: ip})
      assert {:error, _} = Rosary.record_completion(set.id, %{ip: ip})
    end
  end
end
