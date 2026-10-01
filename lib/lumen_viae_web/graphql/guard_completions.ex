defmodule LumenViaeWeb.Graphql.GuardCompletions do
  @moduledoc """
  The GraphQL `recordCompletion` mutation's guard: the same two checks as
  `POST /api/completions` (`LumenViaeWeb.Plugs.GuardCompletions.check/2`),
  run before the mutation resolves. A crawler is turned away on its user
  agent; every address is rate limited, against the same budget the REST
  route spends.

  An Absinthe middleware rather than a plug, because a plug sees one POST
  to `/api/graphql` and cannot tell a completion from a read; only the
  mutation's own field should spend the budget.
  """
  @behaviour Absinthe.Middleware

  alias LumenViaeWeb.Plugs

  @impl true
  def call(%{state: :resolved} = resolution, _config), do: resolution

  def call(resolution, _config) do
    request = get_in(resolution.context, [:context]) || %{}

    case Plugs.GuardCompletions.check(request[:user_agent], request[:client_ip]) do
      :ok ->
        resolution

      {:refuse, _status, code, message} ->
        Absinthe.Resolution.put_result(resolution, {:error, %{message: message, code: code}})
    end
  end
end
