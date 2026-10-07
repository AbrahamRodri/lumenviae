defmodule LumenViaeWeb.RedirectController do
  @moduledoc """
  Answers the addresses of retired pages with a permanent redirect, so a
  bookmark or an old search result lands on the site instead of a 404.
  """
  use LumenViaeWeb, :controller

  def home(conn, _params) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: ~p"/")
  end
end
