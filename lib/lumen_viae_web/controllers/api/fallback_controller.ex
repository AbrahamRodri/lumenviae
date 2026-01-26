defmodule LumenViaeWeb.API.FallbackController do
  use LumenViaeWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: LumenViaeWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: LumenViaeWeb.API.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
