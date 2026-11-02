defmodule LumenViaeWeb.SecurityTxtControllerTest do
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViaeWeb.SecurityTxtController

  @path "/.well-known/security.txt"

  test "unset, as by default, there is no security.txt", %{conn: conn} do
    put_env(:lumen_viae, :security_contact, nil)

    assert conn |> get(@path) |> response(404)
  end

  test "set, it names the contact and an expiry, as plain text", %{conn: conn} do
    put_env(:lumen_viae, :security_contact, "security@example.org")

    conn = get(conn, @path)
    body = response(conn, 200)

    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "text/plain"
    assert body =~ "Contact: mailto:security@example.org\n"
    assert body =~ ~r/^Expires: \d{4}-\d{2}-\d{2}T00:00:00Z$/m
    assert body =~ ~r{^Canonical: https?://[^\s]+/\.well-known/security\.txt$}m
  end

  test "the expiry is 180 days ahead, and a URI contact is kept as it is" do
    body = SecurityTxtController.body("https://example.org/report", ~D[2026-11-02])

    assert body =~ "Contact: https://example.org/report\n"
    assert body =~ "Expires: 2027-05-01T00:00:00Z\n"

    assert SecurityTxtController.body("mailto:a@example.org") =~
             "Contact: mailto:a@example.org\n"
  end
end
