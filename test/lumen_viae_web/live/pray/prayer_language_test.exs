defmodule LumenViaeWeb.Live.Pray.PrayerLanguageTest do
  @moduledoc """
  The prayers can be set in Latin, as the app sets the Rosary when Latin
  is chosen. Only the prayers change: the mysteries, their captions and
  the Scripture stay in English. The choice is this browser's, kept by the
  PrayerMemory hook, never in the URL.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp open_settings(view),
    do: view |> element("button[aria-controls=prayer-settings]") |> render_click()

  defp choose(view, language) do
    view
    |> element(~s(#prayer-settings button[phx-value-language="#{language}"]))
    |> render_click()
  end

  test "the settings offer English, chosen, and Latin", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")
    open_settings(view)

    assert has_element?(
             view,
             ~s(#prayer-settings button[phx-value-language="en"][aria-pressed="true"])
           )

    assert has_element?(
             view,
             ~s(#prayer-settings button[phx-value-language="la"][aria-pressed="false"])
           )

    assert render(view) =~ "Prayer language"
  end

  test "choosing Latin sets the opening prayers in Latin and keeps the choice", %{conn: conn} do
    {:ok, view, html} = live(conn, "/mysteries/joyful/pray")
    assert html =~ "In the name of the Father"

    open_settings(view)
    html = choose(view, "la")

    assert html =~ "Signum Crucis"
    assert html =~ "In nomine Patris"
    assert html =~ "Credo in Deum"
    refute html =~ "In the name of the Father"
    assert html =~ ~s(lang="la")
    assert_push_event(view, "prayer:language", %{language: "la"})

    # Captions stay in English.
    assert html =~ "A Hail Mary for faith"
  end

  test "counting on the screen, the bead's prayer is in Latin", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?count=screen")
    html = render_hook(view, "restore_language", %{"language" => "la"})

    assert view |> element("#bead-0") |> render() =~ "In nomine Patris"
    assert html =~ "Signum Crucis"
  end

  test "a decade's announcement stays in English under Latin prayers", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?mystery=0")
    html = render_hook(view, "restore_language", %{"language" => "la"})

    assert html =~ "The Annunciation"
    assert html =~ "Pater noster"
  end

  test "the language saved in this browser is restored, and nothing else is", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")

    assert render_hook(view, "restore_language", %{"language" => "la"}) =~ "In nomine Patris"
    assert render_hook(view, "restore_language", %{"language" => "fr"}) =~ "In nomine Patris"
    assert render_hook(view, "restore_language", %{}) =~ "In nomine Patris"
  end

  test "an unknown language is ignored", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")
    html = render_click(view, "set_language", %{"language" => "de"})

    assert html =~ "In the name of the Father"
  end

  test "the language is never put in the URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")
    open_settings(view)
    choose(view, "la")
    view |> element("button[phx-click=next]") |> render_click()

    path = assert_patch(view)
    refute path =~ "la"
    assert render(view) =~ "Pater noster"
  end
end
