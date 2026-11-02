defmodule LumenViaeWeb.SecurityTxtController do
  @moduledoc """
  `GET /.well-known/security.txt` (RFC 9116): where to report a security
  problem with the site.

  Off unless `SECURITY_CONTACT` is set, so nobody is named until Abraham
  picks the address; unset, the path is a 404 like any other. The value is
  a `mailto:` or `https:` URI; a bare address gets `mailto:` put in front.
  `Expires`, which the RFC requires, is always 180 days ahead, so a deployed
  file never goes stale.
  """
  use LumenViaeWeb, :controller

  @lifetime_days 180

  def show(conn, _params) do
    case Application.get_env(:lumen_viae, :security_contact) do
      contact when is_binary(contact) and contact != "" ->
        conn
        |> put_resp_content_type("text/plain")
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> send_resp(200, body(contact))

      _unset ->
        conn |> put_resp_content_type("text/plain") |> send_resp(404, "Not Found")
    end
  end

  @doc false
  def body(contact, today \\ Date.utc_today()) do
    expires = today |> Date.add(@lifetime_days) |> Date.to_iso8601()

    """
    Contact: #{uri(contact)}
    Expires: #{expires}T00:00:00Z
    Preferred-Languages: en
    Canonical: #{url(~p"/.well-known/security.txt")}
    """
  end

  defp uri("mailto:" <> _ = contact), do: contact
  defp uri("https://" <> _ = contact), do: contact
  defp uri(address), do: "mailto:" <> address
end
