defmodule LumenViaeWeb.AdminSessionController do
  use LumenViaeWeb, :controller

  def create(conn, %{"password" => password}) do
    admin_password = Application.get_env(:lumen_viae, :admin_password)

    if password == admin_password do
      conn
      |> put_session(:admin_authenticated, true)
      |> put_flash(:info, "Successfully logged in")
      |> redirect(to: "/admin")
    else
      conn
      |> put_flash(:error, "Invalid password")
      |> redirect(to: "/admin/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> delete_session(:admin_authenticated)
    |> put_flash(:info, "Successfully logged out")
    |> redirect(to: "/")
  end
end
