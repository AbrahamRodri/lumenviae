defmodule LumenViae.Rosary.Errors.AudioUnavailable do
  @moduledoc """
  A recording could not be signed: the storage credentials are missing or
  broken. The REST API's 503 `audio_unavailable`; retryable once someone
  fixes the configuration.

  The class is `:invalid` only because AshGraphql shows clients nothing
  outside the `:invalid` and `:forbidden` classes; see
  `LumenViae.Office.Errors.Unavailable`.
  """
  use Splode.Error, fields: [], class: :invalid

  def message(_error), do: "Audio temporarily unavailable"
end

defimpl AshGraphql.Error, for: LumenViae.Rosary.Errors.AudioUnavailable do
  # The fixed text, not Exception.message/1: once the error has passed
  # through an action, Splode prefixes its message with "Bread Crumbs" that
  # name the server's modules, which a client has no business seeing.
  def to_error(_error) do
    message = "Audio temporarily unavailable"

    %{
      message: message,
      short_message: message,
      code: "audio_unavailable",
      vars: %{},
      fields: []
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: LumenViae.Rosary.Errors.AudioUnavailable do
  # The REST API's 503, with the same code. The fixed text, for the reason
  # given above.
  def to_json_api_error(_error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: 503,
      code: "audio_unavailable",
      title: "AudioUnavailable",
      detail: "Audio temporarily unavailable",
      meta: %{}
    }
  end
end
