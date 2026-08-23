defmodule LumenViaeWeb.Live.Pray.CompletionContextTest do
  @moduledoc """
  The website's half of the completion analytics: what a Rosary prayed in a
  browser records, and what a crawler walking the same page does not.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias LumenViae.Repo
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completions.Completion

  @browser "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Version/17.2 Safari/605.1.15"

  defp create_set do
    {:ok, set} =
      Rosary.create_meditation_set(%{
        name: "Web ctx #{System.unique_integer([:positive])}",
        category: "joyful"
      })

    for order <- 1..5 do
      {:ok, mystery} =
        Rosary.create_mystery(%{
          name: "M #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive]),
          description: "d"
        })

      {:ok, meditation} =
        Rosary.create_meditation(%{content: "c", title: "t", mystery_id: mystery.id})

      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order)
    end

    set
  end

  defp last_completion, do: Repo.one(from c in Completion, order_by: [desc: c.id], limit: 1)

  defp press_complete(conn, set) do
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=4")

    view |> element("button[phx-click=complete]") |> render_click()
  end

  test "a Rosary prayed in a browser is recorded as coming from the website", %{conn: conn} do
    set = create_set()

    conn
    |> Plug.Conn.put_req_header("user-agent", @browser)
    |> press_complete(set)

    assert last_completion().source == "web"
  end

  test "the address is truncated before it is stored", %{conn: conn} do
    set = create_set()

    conn
    |> Plug.Conn.put_req_header("user-agent", @browser)
    |> Plug.Conn.put_req_header("x-forwarded-for", "8.8.8.8, 203.0.113.44")
    |> press_complete(set)

    completion = last_completion()

    # The rightmost entry is the one the proxy appended; the leftmost is
    # whatever the caller typed and must not be believed.
    assert completion.ip_prefix == "203.0.113.0"
  end

  test "a crawler that walks the page and trips the button records nothing", %{conn: conn} do
    set = create_set()
    before = Rosary.count_total_completions()

    conn
    |> Plug.Conn.put_req_header(
      "user-agent",
      "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
    )
    |> press_complete(set)

    assert Rosary.count_total_completions() == before
  end
end
