defmodule LumenViaeWeb.Live.Home.InfoPagesTest do
  @moduledoc """
  The pages the footer leads to: the iPhone app's landing page, the
  feedback page and the privacy policy. Each is reached from every public
  page, and each sends the visitor somewhere outside the site (the App
  Store, their mail client), so those doors are what is tested.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @app_store "https://apps.apple.com/us/app/lumen-viae-rosary-meditations/id6760320749"
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

  describe "the app page (/app)" do
    test "presents the iPhone app and its features", %{conn: conn} do
      {:ok, view, html} = live(conn, "/app")

      assert page_title(view) =~ "Lumen Viae for iPhone"

      for feature <- [
            "Guided Audio Rosary",
            "The Daily Mysteries",
            "Meditations of the Saints",
            "Two Ways of Meditating",
            "Listen Anywhere",
            "Free of Distraction"
          ] do
        assert html =~ feature
      end
    end

    test "every download button goes to the App Store listing", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/app")

      links = html |> Floki.parse_document!() |> Floki.find(~s(a[href^="https://apps.apple.com"]))

      assert length(links) >= 2
      assert Enum.all?(links, &(Floki.attribute(&1, "href") == [@app_store]))
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
