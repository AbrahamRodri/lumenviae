defmodule LumenViae.Rosary.Completion.CheckRecord do
  @moduledoc """
  `:check_record_from_app`: `:record_from_app`'s checks with nothing
  written, for the production feature check (`bin/prod-feature-check`),
  which must not record a Rosary nobody prayed.

  It builds the very changeset `:record_from_app` would submit, so the
  crawler check and the source come from the same code, then asks
  `Completion.SetIsVisible` whether the set is one the public can see,
  and stops there. The changeset is never submitted, so its hooks never
  run: no row, no place-lookup job (`Completion.Stamp` enqueues one only
  after a write commits) and nothing spent from the caller's hourly
  budget (`Completion.RateLimit` counts in a hook before the
  transaction). A streak lives on the device and is not touched either.

  It has a small budget of its own instead, per address (security pass NIT
  7): each check costs a query, and only the feature check calls it.
  Past it, the answer is the usual 429.
  """
  use Ash.Resource.Actions.Implementation

  alias AshRateLimiter.LimitExceeded
  alias LumenViae.Limits
  alias LumenViae.Rosary.Completion
  alias LumenViae.Rosary.Completion.SetIsVisible
  alias LumenViae.Rosary.Types.CompletionCheck

  @per_minute 30

  @impl true
  def run(input, _opts, context) do
    with :ok <- within_budget(input.context[:client_ip]), do: check(input, context)
  end

  @doc false
  def per_minute, do: @per_minute

  defp within_budget(ip) when is_binary(ip) do
    key = "completion_check:" <> Limits.address(ip)

    case LumenViae.Hammer.hit(key, 60_000, @per_minute) do
      {:allow, _count} ->
        :ok

      {:deny, _retry_after} ->
        {:error,
         LimitExceeded.exception(
           action: :check_record_from_app,
           limit: @per_minute,
           per: 60_000,
           key: key
         )}
    end
  end

  # No address: the console or a test, as for the hourly limit.
  defp within_budget(_no_address), do: :ok

  defp check(input, context) do
    changeset =
      Ash.Changeset.for_create(
        Completion,
        :record_from_app,
        Map.take(input.arguments, [:meditation_set_id, :prayed_aloud]),
        Keyword.put(Ash.Context.to_opts(context), :context, input.context)
      )

    with :ok <- valid(changeset),
         :ok <- valid(SetIsVisible.validate(changeset, [], context), changeset) do
      {:ok,
       %CompletionCheck{
         meditation_set_id: Ash.Changeset.get_attribute(changeset, :meditation_set_id),
         prayed_aloud: Ash.Changeset.get_attribute(changeset, :prayed_aloud),
         source: Ash.Changeset.get_attribute(changeset, :source)
       }}
    end
  end

  defp valid(%Ash.Changeset{valid?: true}), do: :ok
  defp valid(%Ash.Changeset{errors: errors}), do: {:error, errors}

  defp valid(:ok, _changeset), do: :ok

  defp valid({:error, error}, changeset),
    do: {:error, changeset |> Ash.Changeset.add_error(error) |> Map.fetch!(:errors)}
end
