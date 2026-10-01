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
  def to_error(error) do
    message = Exception.message(error)

    %{
      message: message,
      short_message: message,
      code: "audio_unavailable",
      vars: %{},
      fields: []
    }
  end
end
