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
      # One code for "the request was wrong" across the whole GraphQL API,
      # the same as Ash's own argument errors; the message names the valid
      # values, as the REST API's 400 does.
      code: "invalid_argument",
      vars: %{},
      fields: []
    }
  end
end
