defmodule LumenViae.Rosary.Completion.NotAutomated do
  @moduledoc """
  Refuses a completion from a crawler, on the user agent the server put in
  the action context (`:user_agent`), never one the client named.

  On the action rather than in front of it, so that every API that runs
  `:record_from_app` is covered by declaring it once. GraphQL's guard
  middleware refuses a crawler before the mutation runs, so its answer is
  unchanged; `/api/v2` has no guard of its own and relies on this. The
  predicate and its trade-offs are `LumenViae.BotDetection`'s: a missing
  agent is not a crawler.

  First in the action, so a crawler is turned away before anything else
  runs or counts.
  """
  use Ash.Resource.Validation

  alias LumenViae.BotDetection
  alias LumenViae.Rosary.Errors.AutomatedClient

  @impl true
  def validate(changeset, _opts, _context) do
    if BotDetection.bot?(changeset.context[:user_agent]) do
      {:error, AutomatedClient.exception([])}
    else
      :ok
    end
  end
end
