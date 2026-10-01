defmodule LumenViae.Office.Errors.BadRequest do
  @moduledoc """
  A request the Office cannot answer as asked: a date outside the engine's
  window, an unknown version or language. The message names the valid
  values, the same wording the REST API puts in its 400.
  """
  use Splode.Error, fields: [:message], class: :invalid

  def message(%{message: message}), do: message
end

defimpl AshGraphql.Error, for: LumenViae.Office.Errors.BadRequest do
  def to_error(error) do
    %{
      message: error.message,
      short_message: error.message,
      code: "bad_request",
      vars: %{},
      fields: []
    }
  end
end
