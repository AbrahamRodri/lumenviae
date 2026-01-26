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

  def create(_conn, _params) do
    # Missing meditation_set_id parameter
    {:error, :not_found}
  end
end
