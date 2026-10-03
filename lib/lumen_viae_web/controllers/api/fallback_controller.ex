defmodule LumenViaeWeb.API.FallbackController do
  @moduledoc """
  Turns every `{:error, _}` an API action returns into one error envelope.

  The catch-all clause is the reason this file matters rather than just
  being tidy. `PrayerController.audio` used to hand back `{:error, reason}`
  verbatim from S3, so a missing credential arrived here as
  `{:error, :missing_credentials}`, matched no clause, and raised
  `FunctionClauseError` - the client got a 500 with a stacktrace instead of
  an answer, and nothing was logged that named the actual cause.
  """
  use LumenViaeWeb, :controller

  require Logger

  alias LumenViae.Limits
  alias LumenViae.Rosary
  alias LumenViaeWeb.API.ErrorJSON

  def call(conn, {:error, :not_found}) do
    send_error(conn, :not_found, "not_found", "Not found")
  end

  # Something that was served once and has been taken down for good, as
  # opposed to something that never existed. Only the withdrawn chant
  # recordings answer this today (see PrayerController).
  def call(conn, {:error, :gone}) do
    send_error(conn, :gone, "gone", "This recording has been withdrawn")
  end

  def call(conn, {:error, {:bad_request, message}}) do
    send_error(conn, :bad_request, "bad_request", message)
  end

  def call(conn, {:error, :audio_unavailable}) do
    send_error(conn, :service_unavailable, "audio_unavailable", "Audio temporarily unavailable")
  end

  def call(conn, {:error, :office_unavailable}) do
    send_error(
      conn,
      :service_unavailable,
      "office_unavailable",
      "Divine Office temporarily unavailable"
    )
  end

  # A write the domain refused because the caller has spent its budget
  # (AshRateLimiter's error, which is `forbidden` underneath). Only the
  # completion write limits anything today, and its answer has always been
  # this one.
  def call(conn, {:error, %Ash.Error.Forbidden{} = error} = result) do
    case Limits.exceeded(error) do
      nil -> call_unhandled(conn, result)
      limit -> send_error(conn, :too_many_requests, "rate_limited", Limits.message(limit))
    end
  end

  # A write the domain refused. The details map each field to its
  # messages, read the same way the admin forms read them.
  def call(conn, {:error, %Ash.Error.Invalid{} = error}) do
    send_error(
      conn,
      :unprocessable_entity,
      "validation_failed",
      "The request could not be processed",
      Rosary.error_details(error)
    )
  end

  # Anything an action returns that nothing above anticipated. It answers
  # rather than raising, and it says in the log what it could not name in
  # the response.
  def call(conn, {:error, _reason} = result), do: call_unhandled(conn, result)

  defp call_unhandled(conn, {:error, reason}) do
    Logger.error("Unhandled API error: #{inspect(reason)}")

    send_error(conn, :internal_server_error, "internal_error", "Something went wrong")
  end

  defp send_error(conn, status, code, message, details \\ nil) do
    conn
    |> put_status(status)
    |> put_view(json: ErrorJSON)
    |> render(:error, code: code, message: message, details: details)
  end
end
