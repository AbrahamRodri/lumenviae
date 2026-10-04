defmodule LumenViaeWeb.Live.Admin.CompletionsTest do
  @moduledoc """
  The Completions screen and the report behind it: the figures over a
  period, narrowed by set, surface and aloud, each bar a link to the
  narrower view.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary
  alias LumenViaeWeb.Live.Admin.Completions

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  defp create_set(name) do
    {:ok, set} =
      Rosary.create_meditation_set(%{name: name, category: "joyful"}, actor: admin())

    LumenViae.Test.Sets.with_meditation(set, %{audio_url: "set.mp3"})
  end

  defp complete(set, context) do
    {:ok, _} = Rosary.record_completion(set.id, context)
  end

  test "the report counts, ranks and narrows" do
    joyful = create_set("Report Joyful #{System.unique_integer([:positive])}")
    other = create_set("Report Other #{System.unique_integer([:positive])}")

    complete(joyful, %{source: "web", prayed_aloud: true, locale: "en-US"})
    complete(joyful, %{source: "ios", prayed_aloud: false})
    complete(other, %{source: "web"})

    report = Rosary.completion_report(7, %{}, actor: admin())
    assert report.total == 3
    assert [%{set_id: id, count: 2}, %{count: 1}] = report.sets
    assert id == joyful.id
    assert report.sources == %{"web" => 2, "ios" => 1}
    assert report.locales == [{"en-US", 1}]
    assert length(report.by_day) == 7
    assert report.by_day |> Enum.map(& &1.count) |> Enum.sum() == 3

    assert Rosary.completion_report(7, %{source: "web"}, actor: admin()).total == 2
    assert Rosary.completion_report(7, %{set_id: other.id}, actor: admin()).total == 1
    assert Rosary.completion_report(nil, %{prayed_aloud: true}, actor: admin()).total == 1
    assert Rosary.completion_report(nil, %{}, actor: admin()).by_day == nil
  end

  test "the page draws the period and narrows from the URL", %{conn: conn} do
    set = create_set("Page Set #{System.unique_integer([:positive])}")
    complete(set, %{source: "android"})
    complete(set, %{source: "web"})

    {:ok, _view, html} = live(conn, "/admin/completions")
    assert html =~ "Completions"
    assert html =~ set.name
    assert html =~ "Android app"

    {:ok, view, _html} = live(conn, "/admin/completions?source=android")
    assert has_element?(view, "td", "Android app")
    refute has_element?(view, "td", "Website")
  end

  test "changing a filter patches the URL, leaving out the defaults", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/completions")

    view
    |> form("#completions-filters", %{days: "30", source: "ios", set: "", country: "", aloud: ""})
    |> render_change()

    assert_patch(view, "/admin/completions?source=ios")
  end

  test "a bar's link keeps the other filters" do
    assert Completions.narrow(%{"days" => "7", "source" => "web"}, "set", 12) ==
             "/admin/completions?days=7&set=12&source=web"
  end
end
