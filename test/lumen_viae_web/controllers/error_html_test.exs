defmodule LumenViaeWeb.ErrorHTMLTest do
  use LumenViaeWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  for {status, title} <- [{"404", "Page Not Found"}, {"500", "Something Went Wrong"}] do
    test "#{status} is a page of the site, with a way back" do
      html = render_to_string(LumenViaeWeb.ErrorHTML, unquote(status), "html", [])
      doc = Floki.parse_document!(html)

      assert html =~ "<!DOCTYPE html>"
      assert Floki.find(doc, "html[lang=en]") != []
      assert Floki.find(doc, "h1") |> Floki.text() =~ unquote(title)
      assert [_] = Floki.find(doc, "main")
      assert Floki.find(doc, ~s(a[href="/"])) != []
      assert Floki.find(doc, ~s(a[href="/mysteries"])) != []
    end
  end

  test "404 carries the site's header, with its menu; 500 keeps the bare lockup" do
    not_found =
      LumenViaeWeb.ErrorHTML
      |> render_to_string("404", "html", [])
      |> Floki.parse_document!()

    for path <- ~w(/prayers /chant /hours /explore /app) do
      assert Floki.find(not_found, ~s(header#site-header a[href="#{path}"])) != [],
             "the 404's header leads to #{path}"
    end

    assert Floki.find(not_found, "#mobile-menu-button") != []
    assert Floki.find(not_found, "script[src*='app']") != []

    server_error =
      LumenViaeWeb.ErrorHTML
      |> render_to_string("500", "html", [])
      |> Floki.parse_document!()

    assert Floki.find(server_error, "header#site-header") == []
    assert Floki.find(server_error, "script") == []
  end

  test "a removed novena's 404 says it is gone and leads to the novenas" do
    reason = %LumenViaeWeb.NotFoundError{message: "removed novena", removed: :novena}

    doc =
      LumenViaeWeb.ErrorHTML
      |> render_to_string("404", "html", reason: reason)
      |> Floki.parse_document!()

    assert Floki.find(doc, "h1") |> Floki.text() =~ "Page Not Found"
    assert Floki.find(doc, "main") |> Floki.text() =~ "This novena is no longer on Lumen Viae."
    refute Floki.find(doc, "main") |> Floki.text() =~ "typing error"

    assert [link] = Floki.find(doc, ~s(main a.btn-gold[href="/prayers/topics/novenas"]))
    assert Floki.text(link) =~ "See the novenas"
  end

  test "any other status is its plain message" do
    assert render_to_string(LumenViaeWeb.ErrorHTML, "403", "html", []) == "Forbidden"
  end
end
