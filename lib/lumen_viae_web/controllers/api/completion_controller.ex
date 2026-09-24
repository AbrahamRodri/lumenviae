defmodule LumenViaeWeb.API.CompletionController do
  @moduledoc """
  Records a finished Rosary reported by the iOS app.

  ## What the app sends, and why none of it needs a prompt

  Two optional fields, `time_zone` and `locale`. On iOS both are readable
  from `TimeZone.current` and `Locale.current` with no permission dialog
  and no entry in the app's privacy usage descriptions, because neither is
  a protected resource - they are settings the person chose themselves.

  Deliberately not asked for: Core Location. It would put a system prompt
  between somebody and the end of their Rosary, in exchange for a precision
  the dashboard has no use for. A timezone already answers the question
  worth asking - when do people pray - and the address the request arrives
  from answers roughly where, without anybody being asked anything.

  A third, `prayed_aloud`, says whether the spoken Rosary was on. It is
  a setting inside the app, so it needs no prompt either, and it is dropped
  unless it is a real JSON boolean.

  All three are optional in the strong sense: an older build of the app
  that sends neither still records a completion, and a build that sends
  nonsense records one with the nonsense dropped by the changeset's length
  validations rather than a rejected request.
  """
  use LumenViaeWeb, :controller

  alias LumenViae.Rosary
  alias LumenViaeWeb.ClientIP

  action_fallback LumenViaeWeb.API.FallbackController

  @doc """
  Records a rosary completion.
  """
  def create(conn, %{"meditation_set_id" => set_id} = params) do
    context = %{
      ip: ClientIP.from_conn(conn),
      source: "ios",
      time_zone: string_param(params, "time_zone"),
      locale: string_param(params, "locale"),
      prayed_aloud: boolean_param(params, "prayed_aloud")
    }

    case Rosary.record_completion(set_id, context) do
      {:ok, completion} ->
        conn
        |> put_status(:created)
        |> render(:show, completion: completion)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Was a 404, which said "no such set" for a request that never named one.
  # Nothing consumes the status - APIService.send reads it and nothing else -
  # and the envelope is changing in this commit anyway, so it is worth
  # getting right while the window is open.
  def create(_conn, _params) do
    {:error, {:bad_request, "meditation_set_id is required"}}
  end

  # A JSON body is whatever the caller put in it, so a field that is
  # supposed to be a string may arrive as a number, a list or a map. Only a
  # string is taken; anything else becomes `nil` rather than reaching a
  # changeset that would fail the whole completion over it.
  defp boolean_param(params, key) do
    case Map.get(params, key) do
      value when is_boolean(value) -> value
      _other -> nil
    end
  end

  defp string_param(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        case String.trim(value) do
          "" -> nil
          trimmed -> trimmed
        end

      _other ->
        nil
    end
  end
end
