defmodule LumenViaeWeb.Live.Consecration.State do
  @moduledoc """
  The reader's Consecration on a page's socket: what the
  `ConsecrationPlan` hook read from this browser, assigned as `:plan`,
  `:done`, `:intro_seen?`, `:today` (the browser's date), `:completed_on`
  (the browser's date when a finished plan was completed, else nil) and `:known?`
  (whether the browser has spoken yet). Until it does, the page has no
  plan and the server's date, so a crawler or a browser without
  JavaScript sees every day as anyone may read it.
  """

  import Phoenix.Component, only: [assign: 3]

  alias LumenViaeWeb.Live.Consecration.Plan

  @doc "The state before the browser speaks."
  def init(socket) do
    socket
    |> assign(:plan, nil)
    |> assign(:done, [])
    |> assign(:intro_seen?, false)
    |> assign(:today, Date.utc_today())
    |> assign(:completed_on, nil)
    |> assign(:known?, false)
  end

  @doc "The state the hook pushed (`consecration_state`); anything unreadable is left out."
  def put(socket, params, feasts) when is_map(params) do
    socket
    |> assign(:plan, Plan.parse(params["plan"], feasts))
    |> assign(:done, Plan.parse_done(params["done"]))
    |> assign(:intro_seen?, params["intro_seen"] == true)
    |> assign(:today, Plan.parse_date(params["today"], socket.assigns.today))
    |> assign(:completed_on, Plan.parse_date(params["completed_on"], nil))
    |> assign(:known?, true)
  end

  def put(socket, _params, _feasts), do: assign(socket, :known?, true)
end
