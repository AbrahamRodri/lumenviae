defmodule LumenViaeWeb.Live.Admin.Completions do
  @moduledoc """
  Completions, every way the console can break them down: by day, set,
  surface, place, hour and language, over a period and narrowed by set,
  surface, country or whether the Rosary was prayed aloud.

  The dashboard shows the last 30 days at a glance; this is where its
  completion figures lead. Everything here is one read
  (`LumenViae.Rosary.completion_report/3`), and the filters live in the
  query string, leaving out the defaults, so a URL is a view that can be
  shared. Every bar narrows the page to what it counts.

  Places are best-effort, as on the dashboard, so the coverage sentence
  sits next to them. Times are in the reporting zone.
  """
  use LumenViaeWeb, :live_view

  import LumenViaeWeb.Live.Admin.Dashboard,
    only: [
      place: 1,
      source_label: 1,
      city_label: 1,
      coverage_note: 1,
      source_rows: 1,
      prayed_aloud_rows: 1,
      format_time: 1
    ]

  alias LumenViae.CentralTime
  alias LumenViae.Rosary

  @periods [
    {"Today", "1"},
    {"7 days", "7"},
    {"30 days", "30"},
    {"90 days", "90"},
    {"A year", "365"},
    {"All time", "all"}
  ]
  @default_period "30"
  @filter_keys ~w(days set source country aloud)

  def mount(_params, _session, socket) do
    sets =
      socket.assigns.current_admin
      |> then(&Rosary.list_meditation_sets!(actor: &1))
      |> Enum.sort_by(&String.downcase(&1.name))
      |> Enum.map(&{&1.name, &1.id})

    {:ok,
     socket
     |> assign(:page_title, "Completions")
     |> assign(:set_options, sets)
     |> assign(:period_options, @periods)}
  end

  def handle_params(params, _uri, socket) do
    params = clean(params)

    {:noreply,
     socket
     |> assign(:params, params)
     |> assign(:report, report(params, socket.assigns.current_admin))}
  end

  def handle_event("filter", params, socket) do
    {:noreply, push_patch(socket, to: path(clean(params)))}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: path(%{"days" => socket.assigns.params["days"]}))}
  end

  defp report(params, actor) do
    Rosary.completion_report(
      days(params),
      %{
        set_id: integer(params["set"]),
        source: blank_to_nil(params["source"]),
        country_code: blank_to_nil(params["country"]),
        prayed_aloud: boolean(params["aloud"])
      },
      actor: actor
    )
  end

  defp days(params) do
    case Map.get(params, "days", @default_period) do
      "all" -> nil
      value -> String.to_integer(value)
    end
  end

  @sources ~w(web ios android)

  @doc """
  The query string as the page will use it: only the filters it knows, each
  only when it is a value the page offers (a listed period, a set id, a
  surface, a two-letter country code, true or false). Anything else - a
  list where a string belongs, a period of a million days, a stray key - is
  dropped, so the page falls back to its default rather than failing.
  """
  def clean(params) when is_map(params) do
    for {key, value} <- params, is_binary(value), valid?(key, value), into: %{} do
      {key, value}
    end
  end

  def clean(_params), do: %{}

  defp valid?("days", value), do: Enum.any?(@periods, fn {_label, v} -> v == value end)
  defp valid?("set", value), do: integer(value) != nil
  defp valid?("source", value), do: value in @sources
  defp valid?("country", value), do: value =~ ~r/\A[A-Z]{2}\z/
  defp valid?("aloud", value), do: value in ["true", "false"]
  defp valid?(_key, _value), do: false

  @doc """
  The page's path for `params`, leaving out anything blank and the default
  period, so a URL carries only what differs from the plain view.
  """
  def path(params) do
    query =
      params
      |> Map.take(@filter_keys)
      |> Enum.reject(fn {key, value} ->
        value in [nil, ""] or (key == "days" and value == @default_period)
      end)

    if query == [],
      do: "/admin/completions",
      else: "/admin/completions?" <> URI.encode_query(query)
  end

  @doc "The page's path with one filter set, the others kept: a bar's link."
  def narrow(params, key, value), do: path(Map.put(params, key, to_string(value)))

  @doc "Whether anything but the period narrows the page."
  def filtered?(params),
    do: Enum.any?(~w(set source country aloud), &(params[&1] not in [nil, ""]))

  @doc "The period, as the page's subtitle says it."
  def period_label(params) do
    value = Map.get(params, "days", @default_period)
    Enum.find_value(@periods, "30 days", fn {label, v} -> v == value && label end)
  end

  @doc "Completions per day over the period, to one place."
  def per_day(%{total: total, by_day: [_ | _] = days}), do: Float.round(total / length(days), 1)
  def per_day(_report), do: nil

  @doc "`part` as a whole percentage of `whole`."
  def percent(_part, 0), do: "-"
  def percent(part, whole), do: "#{round(part / whole * 100)}%"

  @doc "Hours of the day, midnight first, each with its count, for a bar list."
  def hour_rows(hours) do
    for hour <- 0..23, count = Map.get(hours, hour, 0), count > 0 do
      %{label: hour_label(hour), count: count}
    end
  end

  defp hour_label(hour) do
    {display, meridiem} =
      cond do
        hour == 0 -> {12, "AM"}
        hour < 12 -> {hour, "AM"}
        hour == 12 -> {12, "PM"}
        true -> {hour - 12, "PM"}
      end

    "#{display} #{meridiem}"
  end

  @doc "The source slug a surface's label was folded from, for its link."
  def source_slug("Website"), do: "web"
  def source_slug("iOS app"), do: "ios"
  def source_slug("Android app"), do: "android"
  def source_slug(_unknown), do: nil

  @doc "The `aloud` value a row of the aloud split narrows to."
  def aloud_value("Prayed aloud"), do: "true"
  def aloud_value("Read silently"), do: "false"
  def aloud_value(_not_reported), do: nil

  def zone, do: CentralTime.abbreviation(DateTime.utc_now())

  defp integer(nil), do: nil

  # A positive id that fits Postgres's integer column.
  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 and int <= 2_147_483_647 -> int
      _ -> nil
    end
  end

  defp boolean("true"), do: true
  defp boolean("false"), do: false
  defp boolean(_), do: nil

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
