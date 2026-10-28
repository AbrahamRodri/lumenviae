defmodule LumenViae.Ops.JobLogTest do
  @moduledoc """
  A failed job attempt is one error line saying which job, how far along,
  what happens next and why.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias LumenViae.Ops.JobLog

  test "a failed attempt is an error line with the job and the first line of the error" do
    job = %Oban.Job{
      id: 42,
      worker: "LumenViae.Curation.Jobs.NarrateMeditation",
      queue: "elevenlabs",
      attempt: 2,
      max_attempts: 5
    }

    log =
      capture_log(fn ->
        JobLog.handle_event(
          [:oban, :job, :exception],
          %{},
          %{
            job: job,
            state: :failure,
            kind: :error,
            reason: %RuntimeError{message: "down\nstack"}
          },
          nil
        )
      end)

    assert log =~
             "[error] job_failed worker=LumenViae.Curation.Jobs.NarrateMeditation queue=elevenlabs " <>
               "id=42 attempt=2/5 state=failure error=RuntimeError: down"

    refute log =~ "stack"
  end

  # An Ash error's message starts with a blank line and a header.
  test "the error is its cause, not a blank line or a header" do
    job = %Oban.Job{id: 7, worker: "W", queue: "q", attempt: 1, max_attempts: 3}

    log =
      capture_log(fn ->
        JobLog.handle_event(
          [:oban, :job, :exception],
          %{},
          %{
            job: job,
            state: :failure,
            kind: :error,
            reason: %RuntimeError{
              message: "\nInvalid Error\n\n* attribute name is required\n  (ash) stack"
            }
          },
          nil
        )
      end)

    assert log =~ "error=RuntimeError: attribute name is required"
  end
end
