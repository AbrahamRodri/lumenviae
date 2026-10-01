defmodule LumenViaeWeb.Graphql.UpstreamBudget do
  @moduledoc """
  Caps how many Divine Office fetches one GraphQL request can ask for.

  Every Office query the cache cannot answer is a request to Divinum
  Officium, a volunteer project's server. Over REST one request asks for
  at most one office. GraphQL lets a client alias a field as often as it
  likes, so a single document could ask for eight hours of each of fifty
  dates and turn one call to us into four hundred calls to them. The
  complexity limit cannot see this: AshGraphql prices a generic action at
  its selection, not at what it fetches.

  So each Office root field is priced at the number of offices it can
  fetch - `officeHours` at eight, the others at one - and a document over
  the budget is refused before anything runs. The budget covers the
  heaviest real use, the app's quiet prefetch of today's and tomorrow's
  hours, with room to spare.
  """
  use Absinthe.Phase

  alias Absinthe.Blueprint
  alias Absinthe.Blueprint.Document.Field
  alias Absinthe.Blueprint.Document.Fragment

  @costs %{
    "officeHour" => 1,
    "officeHours" => 8,
    "officeDay" => 1,
    "officeCalendar" => 1
  }

  @budget 24

  # Absinthe's own defaults for a phase that stops the document: skip to
  # the result phase, so the client gets the error in the usual envelope.
  @abort [jump_phases: true, result_phase: Absinthe.Phase.Document.Result]

  @doc false
  def budget, do: @budget

  @impl Absinthe.Phase
  def run(blueprint, options \\ []) do
    case Blueprint.current_operation(blueprint) do
      nil ->
        {:ok, blueprint}

      operation ->
        cost = cost(operation.selections, blueprint)

        if cost > @budget do
          refuse(blueprint, operation, cost, Map.new(Keyword.merge(@abort, options)))
        else
          {:ok, blueprint}
        end
    end
  end

  defp cost(selections, blueprint) do
    selections
    |> Enum.map(fn
      %Field{name: name} -> Map.get(@costs, name, 0)
      %Fragment.Inline{selections: inner} -> cost(inner, blueprint)
      %Fragment.Spread{name: name} -> spread_cost(name, blueprint)
      _other -> 0
    end)
    |> Enum.sum()
  end

  defp spread_cost(name, blueprint) do
    case Enum.find(blueprint.fragments, &(&1.name == name)) do
      nil -> 0
      fragment -> cost(fragment.selections, blueprint)
    end
  end

  defp refuse(blueprint, operation, cost, options) do
    error = %Absinthe.Phase.Error{
      phase: __MODULE__,
      message:
        "This request asks for #{cost} Divine Office fetches; at most #{@budget} are " <>
          "allowed in one request. Split it into several.",
      locations: [operation.source_location]
    }

    operation =
      operation
      |> flag_invalid(:too_many_upstream_fetches)
      |> put_error(error)

    blueprint = Blueprint.update_current(blueprint, fn _ -> operation end)
    blueprint = put_in(blueprint.execution.validation_errors, [error])

    case options do
      %{jump_phases: true, result_phase: abort_phase} -> {:jump, blueprint, abort_phase}
      _ -> {:error, blueprint}
    end
  end
end
