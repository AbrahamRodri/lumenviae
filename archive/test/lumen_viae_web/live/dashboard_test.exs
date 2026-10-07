defmodule LumenViaeWeb.Live.DashboardTest do
  @moduledoc """
  `/dashboard` is the daily companion: it works out today's mysteries on
  the traditional schedule, in the visitor's own timezone (the
  `UserTimezone` hook sends `set_timezone`), offers the sets for them
  straight into prayer, and points to every other devotion.

  The tests move "today" to a chosen weekday by sending an offset of whole
  days, so they do not depend on the day they run.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary
  alias LumenViae.Test.Sets

  defp visible_set(attrs, meditation_attrs \\ %{}) do
    {:ok, set} =
      Rosary.create_meditation_set(
        Map.merge(%{name: "Set #{System.unique_integer([:positive])}"}, attrs),
        actor: admin()
      )

    Sets.with_meditation(set, meditation_attrs)
  end

  # The offset (in minutes, as the browser reports it: positive west of
  # UTC) that makes the visitor's today fall on `day_of_week`, and that day.
  defp offset_to(day_of_week) do
    today = Date.utc_today()
    days_ahead = Integer.mod(day_of_week - Date.day_of_week(today), 7)

    {-days_ahead * 24 * 60, Date.add(today, days_ahead)}
  end

  defp open_on(conn, day_of_week) do
    {offset, date} = offset_to(day_of_week)
    {:ok, view, _html} = live(conn, "/dashboard")
    html = render_hook(view, "set_timezone", %{"offset" => offset})

    {view, html, date}
  end

  defp devotion_heading(view), do: view |> element("#todays-devotion-heading") |> render()

  test "renders today's Rosary with a week of beads", %{conn: conn} do
    {:ok, view, html} = live(conn, "/dashboard")

    assert html =~ "Today&#39;s Rosary"
    assert page_title(view) =~ "Prayer Dashboard"

    for day <- ~w(Mon Tue Wed Thu Fri Sat Sun), do: assert(html =~ day)
    assert html |> Floki.parse_document!() |> Floki.find(".bead-today") |> length() == 1
  end

  describe "today's devotion follows the visitor's own day" do
    test "Monday is the Joyful Mysteries", %{conn: conn} do
      {view, html, date} = open_on(conn, 1)

      assert devotion_heading(view) =~ "The Joyful Mysteries"
      assert html =~ "Monday&#39;s Devotion"
      assert html =~ Calendar.strftime(date, "%A, %B %-d")
      assert html =~ "The Annunciation"
      assert html =~ "The Finding of Jesus in the Temple"
    end

    test "Tuesday and Friday are the Sorrowful Mysteries", %{conn: conn} do
      for day <- [2, 5] do
        {view, html, _date} = open_on(conn, day)

        assert devotion_heading(view) =~ "The Sorrowful Mysteries"
        assert html =~ "The Agony in the Garden"
      end
    end

    test "Wednesday and Saturday are the Glorious Mysteries", %{conn: conn} do
      for day <- [3, 6] do
        {view, _html, _date} = open_on(conn, day)

        assert devotion_heading(view) =~ "The Glorious Mysteries"
      end
    end

    # The dashboard keeps the traditional schedule: Thursday is not Luminous.
    test "Thursday stays Joyful", %{conn: conn} do
      {view, _html, _date} = open_on(conn, 4)

      assert devotion_heading(view) =~ "The Joyful Mysteries"
      refute devotion_heading(view) =~ "Luminous"
    end
  end

  describe "the sets offered for today" do
    test "are the visible sets of today's category, each straight into prayer",
         %{conn: conn} do
      joyful = visible_set(%{name: "Joyful With Bernard", category: "joyful"})
      visible_set(%{name: "Sorrowful With Liguori", category: "sorrowful"})

      {view, html, _date} = open_on(conn, 1)

      assert html =~ "Choose Your Meditations"
      assert html =~ "Joyful With Bernard"
      refute html =~ "Sorrowful With Liguori"
      assert has_element?(view, ~s(a[href="/meditation-sets/#{joyful.id}/pray"]))
    end

    test "change when the visitor's day does", %{conn: conn} do
      visible_set(%{name: "Joyful With Bernard", category: "joyful"})
      visible_set(%{name: "Sorrowful With Liguori", category: "sorrowful"})

      {view, _html, _date} = open_on(conn, 1)
      {tuesday, _} = offset_to(2)
      html = render_hook(view, "set_timezone", %{"offset" => tuesday})

      assert html =~ "Sorrowful With Liguori"
      refute html =~ "Joyful With Bernard"
    end

    test "mark narrated sets as having guided audio", %{conn: conn} do
      visible_set(%{name: "Narrated", category: "joyful"}, %{audio_url: "narrated.mp3"})

      {_view, html, _date} = open_on(conn, 1)

      assert html =~ "Guided audio available"
    end

    test "leave out a set with nothing in it", %{conn: conn} do
      {:ok, _} =
        Rosary.create_meditation_set(%{name: "Empty Joyful", category: "joyful"}, actor: admin())

      {_view, html, _date} = open_on(conn, 1)

      refute html =~ "Empty Joyful"
      assert html =~ "No meditation sets are available yet for these mysteries."
      assert html =~ "Pray with the Scriptures"
      refute html =~ "Divine Providence"
    end

    test "Divine Providence chooses one of today's sets", %{conn: conn} do
      set = visible_set(%{name: "Only Joyful", category: "joyful"})
      visible_set(%{name: "Only Sorrowful", category: "sorrowful"})

      {view, _html, _date} = open_on(conn, 1)
      to = "/meditation-sets/#{set.id}/pray"

      assert {:error, {:live_redirect, %{to: ^to}}} =
               view |> element("button[phx-click=providence]") |> render_click()
    end
  end

  describe "other devotions" do
    test "list every category but today's", %{conn: conn} do
      {view, _html, _date} = open_on(conn, 1)

      refute has_element?(
               view,
               ~s(section[aria-label="Other devotions"] a[href="/mysteries/joyful"])
             )

      for category <- ~w(sorrowful glorious luminous seven_sorrows) do
        assert has_element?(
                 view,
                 ~s(section[aria-label="Other devotions"] a[href="/mysteries/#{category}"])
               )
      end
    end
  end
end
