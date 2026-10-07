defmodule LumenViaeWeb.Live.Pray.Params do
  @moduledoc """
  The prayer page's URL: where the reader is and how they chose to pray.

  Everything rides in the query string so a reload, a shared link or the
  back button keeps it: `mystery` (`opening`, a decade from 0, or
  `closing`), `step` (the bead on that page, counting on the screen),
  `form`, `count`, `aloud` and `voice`. Defaults are left out to keep
  ordinary links short. `mobile`, from links made before the page worked
  on phones by itself, is accepted and ignored.
  """

  alias LumenViae.Rosary.Voices

  @counts ~w(beads screen)

  @doc """
  The forms a route offers, the default first: a set is prayed with its
  meditations or as the Scriptural Rosary; a category without a set as the
  Scriptural Rosary or with the prayers alone.
  """
  def forms(:set), do: ~w(meditation scriptural)
  def forms(:category), do: ~w(scriptural holy)

  def default_form(route), do: hd(forms(route))

  def form(params, route) do
    if params["form"] in forms(route), do: params["form"], else: default_form(route)
  end

  def count(params), do: if(params["count"] in @counts, do: params["count"], else: "beads")

  def aloud?(params), do: params["aloud"] == "true"

  @doc """
  The page the URL names, given how many decades there are: 0 the
  opening, 1 to `decades` a decade, `decades + 1` the closing. A decade
  number out of range is held to the nearest decade; no `mystery` at all,
  or one that cannot be read, is the beginning.
  """
  def page(params, decades) do
    case params["mystery"] do
      "opening" ->
        0

      "closing" ->
        decades + 1

      value when is_binary(value) ->
        case Integer.parse(value) do
          {n, ""} -> n |> max(0) |> min(decades - 1) |> Kernel.+(1)
          _ -> 0
        end

      _ ->
        0
    end
  end

  def step(params) do
    case Integer.parse(params["step"] || "") do
      {n, ""} when n >= 0 -> n
      _ -> 0
    end
  end

  @doc "How a page is named in the URL."
  def mystery_param(0, _decades), do: "opening"
  def mystery_param(page, decades) when page > decades, do: "closing"
  def mystery_param(page, _decades), do: page - 1

  @doc """
  The URL for `base` (the route's path) at `page` and `step`, with the
  choices in `state`: `route`, `form`, `count`, `aloud`, `voice` and
  `decades`.
  """
  def url(base, state, page, step) do
    query =
      [mystery: mystery_param(page, state.decades)]
      |> then(&if(state.count == "screen", do: &1 ++ [step: step], else: &1))
      |> then(
        &if(state.form != default_form(state.route), do: &1 ++ [form: state.form], else: &1)
      )
      |> then(&if(state.count != "beads", do: &1 ++ [count: state.count], else: &1))
      |> then(&if(state.aloud, do: &1 ++ [aloud: true], else: &1))
      |> then(fn query ->
        if state.voice && state.voice != Voices.default(),
          do: query ++ [voice: state.voice.slug],
          else: query
      end)

    base <> "?" <> URI.encode_query(query)
  end
end
