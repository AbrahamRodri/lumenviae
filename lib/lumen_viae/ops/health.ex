defmodule LumenViae.Ops.Health do
  @moduledoc """
  The answer `GET /healthz` gives: is this machine up, which release is it,
  and can it reach its database.

  Deliberately nothing more. The endpoint is public and unauthenticated, so
  it names no node, no environment and no count. Anything worth knowing
  beyond "up, and talking to Postgres" is on the console's System screen.

  The database is asked `SELECT 1` with a short timeout, in a task so that
  a pool with no free connection, or a database that does not answer, costs
  the check a second and a half rather than the caller's whole timeout.
  """

  alias LumenViae.Repo

  @default_timeout 1_000

  @doc """
  `%{status: "ok" | "error", version: String.t(), db: "ok" | "error"}`.
  `status` is "ok" only when the database answered.
  """
  def check(opts \\ []) do
    db =
      if database_answers?(Keyword.get(opts, :timeout, @default_timeout)), do: "ok", else: "error"

    %{status: db, version: version(), db: db}
  end

  @doc "The release's version, as `mix.exs` names it."
  def version, do: :lumen_viae |> Application.spec(:vsn) |> to_string()

  defp database_answers?(timeout) do
    task =
      Task.async(fn ->
        try do
          Repo.query("SELECT 1", [], timeout: timeout)
        rescue
          exception -> {:error, exception}
        end
      end)

    case Task.yield(task, timeout + 500) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, _result}} -> true
      _no_answer -> false
    end
  end
end
