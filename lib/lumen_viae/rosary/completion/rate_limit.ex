defmodule LumenViae.Rosary.Completion.RateLimit do
  @moduledoc """
  Caps how many completions one address may record in an hour.

  This is the only place the completion limit is written down. Both ways of
  recording a completion carry it, so the REST route, the prayer page and
  GraphQL all spend one budget per address whatever surface they come in by,
  and a surface added later gets the limit by calling the action.

  It is AshRateLimiter's own change, applied with the numbers
  `LumenViae.Limits` reads from the environment when the action runs. The
  `rate_limit` section of the resource is not used because it takes literals,
  and because it has no way to say that a caller with no address is not
  limited.

  ## What it keys on

  The address in the action context (`:client_ip`), which only the server
  can set and the same one `LumenViae.Rosary.Completion.Stamp` truncates for
  storage. It is the full address here and the prefix there: telling
  neighbours apart is the whole job of a limit.

  With no address the limit cannot apply, and the completion is allowed. That
  is the disconnected prayer page, a handful of proxies and the console, not
  an open door.

  ## When it runs

  Before the transaction, so a refused request never takes a database
  connection, and ahead of anything that queries (the app write checks the
  set after it, in a `before_action`, for that reason). A request that is
  refused is still counted, so a caller that keeps hammering stays blocked
  for the rest of the window rather than being let through the moment it
  stops.

  A refusal is an `AshRateLimiter.LimitExceeded` inside an
  `Ash.Error.Forbidden`. Each surface turns it into its own answer; see
  `LumenViae.Limits.exceeded/1`.
  """
  use Ash.Resource.Change

  alias LumenViae.Limits

  @impl true
  def change(changeset, _opts, context) do
    case changeset.context[:client_ip] do
      ip when is_binary(ip) ->
        {change, opts} =
          ip
          |> Limits.completion()
          |> Keyword.put(:on, :before_transaction)
          |> AshRateLimiter.BuiltinChanges.rate_limit()

        {:ok, opts} = change.init(opts)
        change.change(changeset, opts, context)

      _no_address ->
        changeset
    end
  end
end
