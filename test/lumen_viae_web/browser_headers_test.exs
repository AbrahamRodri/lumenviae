defmodule LumenViaeWeb.BrowserHeadersTest do
  @moduledoc """
  What every page sends for its own protection: an encrypted session
  cookie (it carries an admin's token and the client's address; security
  pass NIT 6) and a fuller Content Security Policy, Report-Only for now
  (NIT 2).
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

  # Security pass NIT 2: the fuller policy is sent as Report-Only, beside
  # the enforced default, so it cannot break a page while it is checked.
  test "pages send a fuller Content Security Policy, as Report-Only", %{conn: conn} do
    conn = get(conn, "/")

    assert [policy] = get_resp_header(conn, "content-security-policy-report-only")
    assert policy =~ "default-src 'self'"
    assert policy =~ "object-src 'none'"
    assert [enforced] = get_resp_header(conn, "content-security-policy")
    assert enforced =~ "frame-ancestors 'self'"
  end
end
