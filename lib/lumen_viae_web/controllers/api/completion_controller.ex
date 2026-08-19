defmodule LumenViaeWeb.API.CompletionController do
  use LumenViaeWeb, :controller
  alias LumenViae.Rosary

  action_fallback LumenViaeWeb.API.FallbackController

  @doc """
  Records a rosary completion.
  """
  def create(conn, %{"meditation_set_id" => set_id}) do
    # Pass nil for IP address - just counting completions, no geolocation
    case Rosary.record_completion(set_id, nil) do
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
end
