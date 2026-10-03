defmodule LumenViaeWeb.Graphql.GuardCompletions do
  @moduledoc """
  The GraphQL `recordCompletion` mutation's guard, in two halves around the
  mutation.

  **Before it**, a crawler is turned away on its user agent, the same check
  `POST /api/completions` makes (`LumenViaeWeb.Plugs.GuardCompletions.check/1`).
  An Absinthe middleware rather than a plug, because a plug sees one POST to
  `/api/graphql` and cannot tell a completion from a read; only the
  mutation's own field should be checked.

  **After it**, a refusal from the rate limit is moved to the top level. The
  limit is on the action (see `LumenViae.Limits`), so the
  mutation spends the same per-address budget as REST and the prayer page,
  and what AshGraphql makes of the refusal is the mutation's own `errors`
  list, beside a null `result`. The API has always answered a refusal of the
  request as a top-level error with `data` null, as it does a crawler, and a
  client matches on that; see docs/GRAPHQL.md, "Recording a completion".
  Only a rate limit is moved: a set that does not exist stays where it is.
  """
  @behaviour Absinthe.Middleware

  alias LumenViaeWeb.Plugs

  # The mutation has resolved by the time `:after` runs, so that half has to
  # be matched before the clause that leaves a resolved field alone.
  @impl true
  def call(resolution, :after) do
    case rate_limited(resolution.value) do
      nil -> resolution
      error -> Absinthe.Resolution.put_result(resolution, {:error, error})
    end
  end

  def call(%{state: :resolved} = resolution, _before), do: resolution

  def call(resolution, _before) do
    request = get_in(resolution.context, [:context]) || %{}

    case Plugs.GuardCompletions.check(request[:user_agent]) do
      :ok ->
        resolution

      {:refuse, _status, code, message} ->
        Absinthe.Resolution.put_result(resolution, {:error, %{message: message, code: code}})
    end
  end

  defp rate_limited(%{errors: errors}) when is_list(errors) do
    case Enum.find(errors, &(Map.get(&1, :code) == "rate_limited")) do
      nil -> nil
      error -> %{message: error.message, code: "rate_limited"}
    end
  end

  defp rate_limited(_value), do: nil
end
