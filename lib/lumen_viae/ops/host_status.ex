defmodule LumenViae.Ops.HostStatus do
  @moduledoc """
  What the server's own timers last reported: the nightly backup, the
  weekly restore test and the 15-minute system check (deploy/vm/bin/backup,
  restore-test and system-check). Each writes a small JSON file into the
  stack's `status/` folder, which compose.yml mounts read-only into the app
  at `OPS_STATUS_DIR`; this reads them and nothing else.

  A file that is missing, unreadable or not the expected JSON is
  `:not_reported`, never an error: a laptop has no such folder, and a
  server whose timers have not run since the folder appeared has nothing
  to say yet.

  Each file is `{"ok": true|false, "at": "<UTC ISO 8601>", "detail": "..."}`;
  the system check adds `disk_percent` and `free_percent`. No secret, path
  or address is written into them.
  """

  @checks [backup: "backup.json", restore_test: "restore-test.json", system: "system-check.json"]

  @doc "The checks, in the order the System page shows them."
  def names, do: Keyword.keys(@checks)

  @doc """
  `%{backup:, restore_test:, system:}`, each `:not_reported` or
  `%{ok?:, at:, detail:, disk_percent:, free_percent:}` (the last two nil
  except for the system check).
  """
  def read(dir \\ dir()) do
    Map.new(@checks, fn {name, file} -> {name, read_file(dir, file)} end)
  end

  defp dir, do: System.get_env("OPS_STATUS_DIR")

  defp read_file(nil, _file), do: :not_reported

  defp read_file(dir, file) do
    with {:ok, body} <- File.read(Path.join(dir, file)),
         {:ok, %{"ok" => ok, "at" => at} = json} when is_boolean(ok) <- Jason.decode(body),
         {:ok, at, _offset} <- DateTime.from_iso8601(at) do
      %{
        ok?: ok,
        at: at,
        detail: text(json["detail"]),
        disk_percent: integer(json["disk_percent"]),
        free_percent: integer(json["free_percent"])
      }
    else
      _missing_or_malformed -> :not_reported
    end
  end

  defp text(value) when is_binary(value), do: String.slice(value, 0, 300)
  defp text(_other), do: nil

  defp integer(value) when is_integer(value), do: value
  defp integer(_other), do: nil
end
