defmodule LumenViaeWeb.SessionCookieTest do
  @moduledoc """
  The session cookie carries an admin's token and the client's address, so
  it is encrypted, not only signed (security pass NIT 6): its value is an
  encrypted token, and none of the session's words show in it.
  """
  use LumenViaeWeb.ConnCase, async: true

  test "the session cookie is encrypted", %{conn: conn} do
    conn = get(conn, "/admin/login")

    assert %{value: value} = conn.resp_cookies["_lumen_viae_key"]

    # Plug.Crypto's encrypted tokens begin "XCP." (older ones "QTEyOEdDTQ",
    # "A128GCM" in base64); a signed-only cookie begins "SFMyNTY" (HS256),
    # its session readable as base64.
    assert String.starts_with?(value, "XCP.") or String.starts_with?(value, "QTEyOEdDTQ")
    refute String.starts_with?(value, "SFMyNTY")
    refute value =~ Base.url_encode64("_csrf_token", padding: false)
  end
end
