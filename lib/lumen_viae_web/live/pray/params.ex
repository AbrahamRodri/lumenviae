defmodule LumenViaeWeb.Live.Pray.Params do
  @moduledoc """
  The prayer page's URL: where the reader is and how they chose to pray.

  Everything rides in the query string so a reload, a shared link or the
  back button keeps it: `mystery` (`opening`, a decade from 0, or
  `closing`), `step` (the bead on that page, counting on the screen),
  `form`, `count`, `aloud` and `voice`. Defaults are left out to keep
  ordinary links short.

  How the beads are counted and whether the Rosary is said aloud default
  by form. The Rosary Said Aloud (`holy`), as the app prays it, is the
  whole Rosary aloud with the beads on the screen; every other form is
  silent and counted on the reader's own rosary. A URL that says otherwise
  (`aloud=false`, `count=beads`) is followed, and only a choice away from
  its form's default is written into a URL. `mobile`, from links made before the page worked
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

  @doc "How the beads are counted in `form` unless the URL says otherwise."
  def default_count("holy"), do: "screen"
  def default_count(_form), do: "beads"

  @doc "Whether `form` is said aloud unless the URL says otherwise."
  def default_aloud?("holy"), do: true
  def default_aloud?(_form), do: false

  def count(params, form \\ nil) do
    if params["count"] in @counts, do: params["count"], else: default_count(form)
  end

  def aloud?(params, form \\ nil) do
    case params["aloud"] do
      "true" -> true
      "false" -> false
      _other -> default_aloud?(form)
    end
  end

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

  def step(%{"step" => step}) when is_binary(step) do
    case Integer.parse(step) do
      {n, ""} when n >= 0 -> n
      _ -> 0
    end
  end

  # Absent, or not a string at all (`step[]=1` arrives as a list).
  def step(_params), do: 0

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
      |> then(
        &if(state.count != default_count(state.form), do: &1 ++ [count: state.count], else: &1)
      )
      |> then(
        &if(state.aloud != default_aloud?(state.form), do: &1 ++ [aloud: state.aloud], else: &1)
      )
      |> then(fn query ->
        if state.voice && state.voice != Voices.default(),
          do: query ++ [voice: state.voice.slug],
          else: query
      end)

    base <> "?" <> URI.encode_query(query)
  end
end
