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

  alias LumenViaeWeb.API.ErrorJSON

  def call(conn, {:error, :not_found}) do
    send_error(conn, :not_found, "not_found", "Not found")
  end

  def call(conn, {:error, {:bad_request, message}}) do
    send_error(conn, :bad_request, "bad_request", message)
  end

  def call(conn, {:error, :audio_unavailable}) do
    send_error(conn, :service_unavailable, "audio_unavailable", "Audio temporarily unavailable")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    send_error(
      conn,
      :unprocessable_entity,
      "validation_failed",
      "The request could not be processed",
      translate_errors(changeset)
    )
  end

  # Anything an action returns that nothing above anticipated. It answers
  # rather than raising, and it says in the log what it could not name in
  # the response.
  def call(conn, {:error, reason}) do
    Logger.error("Unhandled API error: #{inspect(reason)}")

    send_error(conn, :internal_server_error, "internal_error", "Something went wrong")
  end

  defp send_error(conn, status, code, message, details \\ nil) do
    conn
    |> put_status(status)
    |> put_view(json: ErrorJSON)
    |> render(:error, code: code, message: message, details: details)
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
