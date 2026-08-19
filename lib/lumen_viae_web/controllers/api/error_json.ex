defmodule LumenViaeWeb.API.ErrorJSON do
  @moduledoc """
  The one shape every API error is answered with.

      {"error": {"code": "not_found", "message": "Not found"}}

  `code` is a stable machine-readable string the client may branch on;
  `message` is for a human reading a log and is free to change. `details` is
  present only when there is something per-field to say, and is then a map of
  field name to a list of messages.

  One shape rather than two: before this, a 404 rendered
  `%{errors: %{detail: ...}}` from the default Phoenix view and a 422
  rendered `%{errors: %{field: [...]}}` from a separate one, so a client had
  to know which endpoint it was talking to before it could read the error.
  Neither was consumed - `APIService.send` reads only the status code - which
  made this a free window to fix.
  """

  @doc """
  Renders the envelope. `:details` is optional and omitted when absent.
  """
  def error(%{code: code, message: message} = assigns) do
    envelope = %{code: code, message: message}

    case Map.get(assigns, :details) do
      nil -> %{error: envelope}
      details -> %{error: Map.put(envelope, :details, details)}
    end
  end
end
