defmodule LumenViae.MailerTest do
  # idna is overridden to 8.x in mix.exs, past swoosh's "< 8.0.0" cap, for
  # EEF-CVE-2026-117678. Swoosh punycode-encodes a recipient's domain with
  # :idna.utf8_to_ascii/1; these pin that it still does so under idna 8.
  use ExUnit.Case, async: true

  import Swoosh.TestAssertions

  alias Swoosh.Email.Render

  test "a non-ASCII domain is punycode-encoded" do
    assert Render.render_recipient({"", "lector@bücher.example"}) ==
             "lector@xn--bcher-kva.example"

    assert Render.render_recipient({"Lector", "lector@ñandú.example"}) ==
             "\"Lector\" <lector@xn--and-6ma2c.example>"
  end

  test "an ASCII address is unchanged" do
    assert Render.render_recipient({nil, "admin@lumenviae.org"}) == "admin@lumenviae.org"
  end

  test "the mailer delivers to a non-ASCII domain" do
    email =
      Swoosh.Email.new(
        to: {"Lector", "lector@bücher.example"},
        from: {"Lumen Viae", "noreply@lumenviae.org"},
        subject: "Prueba",
        text_body: "Hola"
      )

    assert {:ok, _} = LumenViae.Mailer.deliver(email)
    assert_email_sent(subject: "Prueba")
  end
end
