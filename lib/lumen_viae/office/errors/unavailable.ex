defmodule LumenViae.Office.Errors.Unavailable do
  @moduledoc """
  The Divinum Officium engine could not be reached, answered with an
  error, or answered markup the parser no longer recognizes. One retryable
  answer for the client, as the REST API's 503 is; the distinction is in
  the server log.

  The class is `:invalid` even though nothing about the request was wrong.
  AshGraphql shows a client only errors of the `:invalid` and `:forbidden`
  classes and replaces every other one with "something went wrong", which
  is right for a crash and wrong for a known condition the client should
  retry. The class decides nothing else here: the REST API never sees this
  error, and its 503 comes from `LumenViae.Office` directly.
  """
  use Splode.Error, fields: [], class: :invalid

  def message(_error), do: "Divine Office temporarily unavailable"
end

defimpl AshGraphql.Error, for: LumenViae.Office.Errors.Unavailable do
  # The fixed text, not Exception.message/1: once the error has passed
  # through an action, Splode prefixes its message with "Bread Crumbs" that
  # name the server's modules, which a client has no business seeing.
  def to_error(_error) do
    message = "Divine Office temporarily unavailable"

    %{
      message: message,
      short_message: message,
      code: "office_unavailable",
      vars: %{},
      fields: []
    }
  end
end
