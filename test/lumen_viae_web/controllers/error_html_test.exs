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

  test "any other status is its plain message" do
    assert render_to_string(LumenViaeWeb.ErrorHTML, "403", "html", []) == "Forbidden"
  end
end
