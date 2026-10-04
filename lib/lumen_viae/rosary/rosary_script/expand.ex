defmodule LumenViae.Rosary.RosaryScript.Expand do
  @moduledoc """
  Answers a `LumenViae.Rosary.RosaryScript` read with the Rosary its
  arguments describe, expanded by `LumenViae.Rosary.PrayerAudio.script/3`.
  A value it does not know is an `invalid_argument` naming the ones it
  does.
  """
  use Ash.Resource.Preparation

  alias Ash.DataLayer.Simple
  alias Ash.Error.Query.InvalidArgument
  alias LumenViae.Rosary.{Categories, Content, PrayerAudio, RosaryScript, Types}

  @impl true
  def prepare(query, _opts, _context) do
    script = Content.script()

    with {:ok, category} <- category(Ash.Query.get_argument(query, :category)),
         {:ok, style} <- style(Ash.Query.get_argument(query, :style), script),
         {:ok, extras} <- extras(Ash.Query.get_argument(query, :extras), script),
         {:ok, orders} <- orders(Ash.Query.get_argument(query, :orders), category, script) do
      steps =
        category
        |> PrayerAudio.script(orders, style: style, closing: extras)
        |> Enum.map(&step/1)

      # The chaplet takes no optional prayers, so none are said.
      extras = if form(category, script)["takes_extras"], do: extras, else: []

      record =
        struct(RosaryScript, %{
          id: Enum.join([category, style, Enum.join(extras, ","), Enum.join(orders, ",")], ":"),
          category: category,
          style: style,
          extras: extras,
          orders: orders,
          steps: steps
        })

      Simple.set_data(query, [record])
    else
      {:error, field, message} ->
        Ash.Query.add_error(query, InvalidArgument.exception(field: field, message: message))
    end
  end

  defp category(category) do
    if category in Categories.slugs(),
      do: {:ok, category},
      else: {:error, :category, "category must be one of: #{Enum.join(Categories.slugs(), ", ")}"}
  end

  defp style(style, _script) when style in [nil, ""], do: {:ok, "meditation"}

  defp style(style, %{"styles" => styles}) do
    if style in styles,
      do: {:ok, style},
      else: {:error, :style, "style must be one of: #{Enum.join(styles, ", ")}"}
  end

  # The chosen ones in the order they are said, whatever order they came in.
  defp extras(extras, %{"closing_extras" => known}) do
    ids = Enum.map(known, & &1["id"])
    chosen = split(extras)

    case chosen -- ids do
      [] ->
        {:ok, Enum.filter(ids, &(&1 in chosen))}

      _ ->
        {:error, :extras, "extras must be any of: #{Enum.join(ids, ", ")}, separated by commas"}
    end
  end

  defp orders(orders, category, script) do
    decades = form(category, script)["strand"]["decades"]

    case split(orders) do
      [] ->
        {:ok, Enum.to_list(1..decades)}

      given ->
        parsed = Enum.map(given, &Integer.parse/1)

        if Enum.all?(parsed, &match?({n, ""} when n in 1..decades//1, &1)),
          do: {:ok, Enum.map(parsed, &elem(&1, 0))},
          else:
            {:error, :orders, "orders must be numbers from 1 to #{decades}, separated by commas"}
    end
  end

  defp form(category, script),
    do:
      Enum.find_value(
        ["rosary", "chaplet"],
        &(category in script[&1]["categories"] && script[&1])
      )

  defp split(value) when value in [nil, ""], do: []

  defp split(value),
    do: value |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

  defp step(step) do
    %Types.ScriptStep{
      kind: Atom.to_string(step.kind),
      name: step.name,
      mystery: step.mystery,
      caption: step.caption,
      phase: Atom.to_string(step.phase),
      decade: step.decade,
      bead: step.bead,
      place: step.place,
      pause_ms: step.pause_ms
    }
  end
end
