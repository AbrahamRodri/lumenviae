defmodule LumenViae.Rosary.Errors.AutomatedClient do
  @moduledoc """
  A crawler tried to record a completion. The REST API's 403
  `automated_client`, with the same message; never worth retrying.

  Raised by `LumenViae.Rosary.Completion.NotAutomated`. The class is
  `:forbidden` so that it is a refusal of the caller, not of a value the
  caller sent.
  """
  use Splode.Error, fields: [], class: :forbidden

  @message "Automated clients cannot record completions"

  def message(_error), do: @message

  @doc false
  def text, do: @message
end

defimpl AshJsonApi.ToJsonApiError, for: LumenViae.Rosary.Errors.AutomatedClient do
  # The fixed text: once the error has passed through an action, Splode
  # prefixes its message with "Bread Crumbs" that name the server's modules.
  def to_json_api_error(_error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: 403,
      code: "automated_client",
      title: "AutomatedClient",
      detail: LumenViae.Rosary.Errors.AutomatedClient.text(),
      meta: %{}
    }
  end
end

defimpl AshGraphql.Error, for: LumenViae.Rosary.Errors.AutomatedClient do
  # GraphQL's guard refuses a crawler before the mutation runs, so this is
  # only reached if that guard is ever bypassed; it answers the same way.
  def to_error(_error) do
    message = LumenViae.Rosary.Errors.AutomatedClient.text()

    %{
      message: message,
      short_message: message,
      code: "automated_client",
      vars: %{},
      fields: []
    }
  end
end
