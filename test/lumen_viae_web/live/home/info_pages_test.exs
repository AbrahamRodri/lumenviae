defmodule LumenViaeWeb.Live.Home.InfoPagesTest do
  @moduledoc """
  The privacy policy, which the App Store listing links to, and the footer
  that leads to it from every public page.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @contact "rodriguez.abrahamdev@gmail.com"

  describe "the footer" do
    # The footer is in the root layout, outside the LiveView, so it is read
    # from the full page the server sends.
    test "on every public page leads to the mysteries and the privacy policy",
         %{conn: conn} do
      for page <- ["/", "/mysteries", "/mysteries/joyful", "/privacy-policy"] do
        footer =
          conn
          |> get(page)
          |> html_response(200)
          |> Floki.parse_document!()
          |> Floki.find("footer")

        for {path, label} <- [
              {"/mysteries/joyful", "Joyful"},
              {"/mysteries/seven_sorrows", "Seven Sorrows"},
              {"/mysteries", "Mysteries in Scripture"},
              {"/privacy-policy", "Privacy Policy"}
            ] do
          link = Floki.find(footer, ~s(a[href="#{path}"]))

          assert link != [], "#{page} has no footer link to #{path}"
          assert Floki.text(link) =~ label
        end
      end
    end
  end

  describe "the header" do
    defp page(conn, path), do: conn |> get(path) |> html_response(200) |> Floki.parse_document!()

    test "marks the page it is on, and only that one", %{conn: conn} do
      doc = page(conn, "/mysteries/joyful")

      current = Floki.find(doc, ~s(header [aria-current="page"]))
      assert current != []
      assert Enum.all?(Floki.attribute(current, "href"), &(&1 == "/mysteries/joyful"))

      assert page(conn, "/privacy-policy") |> Floki.find(~s(header [aria-current])) == []
    end

    test "each menu button names the menu it opens, closed to begin with", %{conn: conn} do
      doc = page(conn, "/")

      for button <- ["#mysteries-menu-button", "#mobile-menu-button"] do
        [menu_id] = doc |> Floki.find(button) |> Floki.attribute("aria-controls")

        assert Floki.attribute(Floki.find(doc, button), "aria-expanded") == ["false"]
        assert Floki.find(doc, "##{menu_id}.hidden") != []
      end
    end

    test "is skipped by the first link on the page", %{conn: conn} do
      doc = page(conn, "/privacy-policy")

      assert [first | _] = Floki.find(doc, "body a")
      assert Floki.attribute(first, "href") == ["#main-content"]
      assert Floki.find(doc, "main#main-content") != []
    end
  end

  describe "the privacy policy (/privacy-policy)" do
    test "has every section a reader looks for", %{conn: conn} do
      {:ok, view, html} = live(conn, "/privacy-policy")

      assert page_title(view) =~ "Privacy Policy"
      assert html =~ ~r/Last updated: \w+ \d{1,2}, \d{4}/

      for heading <- [
            "Information We Collect",
            "Information We Do Not Collect",
            "What Stays on Your Phone",
            "How We Use the Information",
            "Data Retention",
            "Third-Party Services",
            "Children&#39;s Privacy",
            "Changes to This Policy",
            "Contact"
          ] do
        assert html =~ heading
      end

      assert has_element?(view, ~s(a[href="mailto:#{@contact}"]))
    end

    # These promises are what the completion code does (truncated prefix,
    # no device id, place from the address alone). If one of them changes,
    # the policy has to change in the same commit.
    test "states the completion analytics commitments", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/privacy-policy")
      html = String.replace(html, ~r/\s+/, " ")

      assert html =~ "We do not save your full network address"
      assert html =~ "the first three parts of an IPv4 address"
      assert html =~ "the first three groups of an IPv6 one"
      assert html =~ "We do not attach any account, device or installation identifier"
      assert html =~ "never ask your device where it is"
      assert html =~ "ipapi.co"
    end
  end
end
