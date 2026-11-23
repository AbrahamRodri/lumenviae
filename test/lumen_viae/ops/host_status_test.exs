defmodule LumenViae.Ops.HostStatusTest do
  @moduledoc """
  What the server's timers write for the System page (deploy/vm/bin/write-status),
  read back, and anything missing or malformed reported as not reported.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Ops.HostStatus

  @moduletag :tmp_dir

  test "reads each timer's report", %{tmp_dir: dir} do
    File.write!(
      Path.join(dir, "system-check.json"),
      ~s|{"ok":true,"at":"2026-11-23T17:24:00Z","detail":"running: app db","disk_percent":40,"free_percent":65}|
    )

    File.write!(
      Path.join(dir, "backup.json"),
      ~s|{"ok":false,"at":"2026-11-23T03:35:00Z","detail":"failed (exit 1)"}|
    )

    status = HostStatus.read(dir)

    assert %{ok?: true, at: ~U[2026-11-23 17:24:00Z], disk_percent: 40, free_percent: 65} =
             status.system

    assert %{ok?: false, detail: "failed (exit 1)", disk_percent: nil} = status.backup
    assert status.restore_test == :not_reported
  end

  test "a malformed file, or no folder at all, is not reported", %{tmp_dir: dir} do
    File.write!(Path.join(dir, "backup.json"), "not json")
    File.write!(Path.join(dir, "restore-test.json"), ~s|{"ok":"yes","at":"never"}|)

    assert %{backup: :not_reported, restore_test: :not_reported, system: :not_reported} =
             HostStatus.read(dir)

    assert HostStatus.read(nil) ==
             %{backup: :not_reported, restore_test: :not_reported, system: :not_reported}
  end
end
