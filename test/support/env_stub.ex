defmodule LumenViae.Test.EnvStub do
  @moduledoc """
  Overrides application environment for the duration of a test and puts it
  back afterwards.

  The subtlety this exists for: **a key set to nil and a key that was never
  set are different things.** `config/runtime.exs` sets
  `:ex_aws, :access_key_id` to `System.get_env("AWS_ACCESS_KEY_ID")`, which is
  nil under test, so the key is present carrying nil. Restoring it by
  deleting it instead of writing the nil back leaves ExAws with no entry at
  all, so it falls back to its default credential chain - and the next call
  that resolves credentials tries the EC2 instance metadata endpoint and
  blocks until the connection times out.

  That failed intermittently and far away from the cause: a completely
  unrelated test exiting on a `GenServer.call` to `ExAws.Config.AuthCache`,
  and the suite occasionally taking eight seconds instead of half of one.

  `Application.fetch_env/2` is the whole fix, because it tells the two cases
  apart. It lives here rather than in each test file so there is one copy to
  get right.
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @doc """
  Sets each `{app, key, value}` and restores the previous state when the test
  ends.
  """
  def put_env(overrides) when is_list(overrides) do
    restore = snapshot(Enum.map(overrides, fn {app, key, _value} -> {app, key} end))

    Enum.each(overrides, fn {app, key, value} -> Application.put_env(app, key, value) end)

    on_exit(restore)
    :ok
  end

  def put_env(app, key, value), do: put_env([{app, key, value}])

  @doc """
  Captures the current state of each `{app, key}` and returns a zero-arity
  function that puts it back.

  Separate from `put_env/1` so the restoring itself can be tested: `on_exit`
  only runs once a test is already over, which is too late to assert on.
  """
  def snapshot(keys) do
    captured = Enum.map(keys, fn {app, key} -> {app, key, Application.fetch_env(app, key)} end)

    fn ->
      Enum.each(captured, fn
        {app, key, {:ok, value}} -> Application.put_env(app, key, value)
        {app, key, :error} -> Application.delete_env(app, key)
      end)
    end
  end
end
