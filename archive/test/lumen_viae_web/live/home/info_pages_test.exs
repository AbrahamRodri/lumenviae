defmodule LumenViaeWeb.Live.Home.InfoPagesTest do
  @moduledoc """
  The pages the footer led to: the feedback page and the privacy policy.
  The iPhone app's page came back to the site on 7 October 2026; its tests
  are in test/lumen_viae_web/live/home/app_test.exs.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @contact "rodriguez.abrahamdev@gmail.com"

  describe "the footer" do
    # The footer is in the root layout, outside the LiveView, so it is read
    # from the full page the server sends.
    test "on every public page leads to the app, feedback and privacy pages",
         %{conn: conn} do
      for page <- ["/", "/dashboard", "/mysteries/joyful", "/privacy-policy"] do
        footer =
          conn
          |> get(page)
          |> html_response(200)
          |> Floki.parse_document!()
          |> Floki.find("footer")

        for {path, label} <- [
              {"/app", "The App"},
              {"/feedback", "Feedback"},
              {"/privacy-policy", "Privacy Policy"}
            ] do
          link = Floki.find(footer, ~s(a[href="#{path}"]))

          assert link != [], "#{page} has no footer link to #{path}"
          assert Floki.text(link) =~ label
        end
      end
    end
  end

  describe "the feedback page (/feedback)" do
    test "opens a mail to the contact address with the subject already written",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/feedback")

      assert page_title(view) =~ "Share Feedback"

      assert has_element?(
               view,
               ~s(a[href="mailto:#{@contact}?subject=Lumen+Viae+Issue+Report"])
             )

      assert has_element?(
               view,
               ~s(a[href="mailto:#{@contact}?subject=Lumen+Viae+Feature+Request"])
             )

      assert has_element?(view, ~s(a[href="mailto:#{@contact}"]))
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
