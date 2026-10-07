defmodule LumenViaeWeb.Live.HomeTodayTest do
  @moduledoc """
  `/` is the daily Rosary hub: it works out today's mysteries on the
  traditional schedule, in the visitor's own timezone (the `UserTimezone`
  hook sends `set_timezone`), offers the sets for them straight into
  prayer, the set-less forms of the Rosary, and every category.

  The tests move "today" to a chosen weekday by sending an offset of whole
  days, so they do not depend on the day they run. The mysteries' own
  names and paintings come from the database and are tested in
  `LumenViaeWeb.Live.HomeMysteriesTest`, which is not async.
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
  # UTC) that makes the visitor's today fall on `day_of_week`.
  defp offset_to(day_of_week) do
    days_ahead = Integer.mod(day_of_week - Date.day_of_week(Date.utc_today()), 7)
    -days_ahead * 24 * 60
  end

  defp open_on(conn, day_of_week) do
    {:ok, view, _html} = live(conn, "/")
    html = render_hook(view, "set_timezone", %{"offset" => offset_to(day_of_week)})
    {view, html}
  end

  defp devotion_heading(view), do: view |> element("#todays-devotion-heading") |> render()

  test "renders the hero with a week of beads", %{conn: conn} do
    {:ok, view, html} = live(conn, "/")

    assert html =~ "The Rosary, Illuminated"
    assert page_title(view) =~ "Meditations on the Holy Rosary"

    for day <- ~w(Mon Tue Wed Thu Fri Sat Sun), do: assert(html =~ day)
    assert html |> Floki.parse_document!() |> Floki.find(".bead-today") |> length() == 1
  end

  test "has one h1 and links no retired page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    doc = Floki.parse_document!(html)

    assert doc |> Floki.find("main h1") |> length() == 1

    hrefs = doc |> Floki.find("main a") |> Floki.attribute("href")

    for retired <- ~w(/dashboard /app /rosary-methods /true-devotion /saint-carlo /feedback) do
      refute retired in hrefs
    end
  end

  test "describes itself without the retired methods page", %{conn: conn} do
    html = conn |> get("/") |> html_response(200)

    [description] =
      html
      |> Floki.parse_document!()
      |> Floki.find(~s(meta[name="description"]))
      |> Floki.attribute("content")

    assert description =~ "Rosary"
    refute description =~ "Montfort"
  end

  describe "today's devotion follows the visitor's own day" do
    test "Monday is the Joyful Mysteries, with the way in", %{conn: conn} do
      {view, html} = open_on(conn, 1)

      assert devotion_heading(view) =~ "The Joyful Mysteries"
      assert html =~ "Monday&#39;s Devotion"
      assert has_element?(view, ~s(#pray-today[href="/mysteries/joyful"]))
    end

    test "Tuesday and Friday are the Sorrowful Mysteries", %{conn: conn} do
      for day <- [2, 5] do
        {view, _html} = open_on(conn, day)

        assert devotion_heading(view) =~ "The Sorrowful Mysteries"
        assert has_element?(view, ~s(#pray-today[href="/mysteries/sorrowful"]))
      end
    end

    test "Wednesday and Saturday are the Glorious Mysteries", %{conn: conn} do
      for day <- [3, 6] do
        {view, _html} = open_on(conn, day)

        assert devotion_heading(view) =~ "The Glorious Mysteries"
      end
    end

    # The home page keeps the traditional schedule: Thursday is not Luminous.
    test "Thursday stays Joyful", %{conn: conn} do
      {view, _html} = open_on(conn, 4)

      assert devotion_heading(view) =~ "The Joyful Mysteries"
      refute devotion_heading(view) =~ "Luminous"
    end

    test "a fallback list of mysteries stands in until they are in the database",
         %{conn: conn} do
      {view, _html} = open_on(conn, 1)

      mysteries = view |> element("#todays-mysteries") |> render()

      assert mysteries =~ "The First Joyful Mystery"
      assert mysteries =~ "The Fifth Joyful Mystery"
    end

    test "an offset that is not one is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      before = devotion_heading(view)

      render_hook(view, "set_timezone", %{"offset" => "west"})
      render_hook(view, "set_timezone", %{"offset" => 10_000_000})

      assert devotion_heading(view) == before
    end
  end

  describe "the sets offered for today" do
    test "are the visible sets of today's category, each straight into prayer",
         %{conn: conn} do
      joyful = visible_set(%{name: "Joyful With Bernard", category: "joyful"})
      visible_set(%{name: "Sorrowful With Liguori", category: "sorrowful"})

      {view, html} = open_on(conn, 1)

      assert html =~ "Pray with the Saints"
      assert html =~ "Joyful With Bernard"
      refute html =~ "Sorrowful With Liguori"
      assert has_element?(view, ~s(#todays-sets a[href="/meditation-sets/#{joyful.id}/pray"]))
    end

    test "change when the visitor's day does", %{conn: conn} do
      visible_set(%{name: "Joyful With Bernard", category: "joyful"})
      visible_set(%{name: "Sorrowful With Liguori", category: "sorrowful"})

      {view, _html} = open_on(conn, 1)
      html = render_hook(view, "set_timezone", %{"offset" => offset_to(2)})

      assert html =~ "Sorrowful With Liguori"
      refute html =~ "Joyful With Bernard"
    end

    test "mark narrated sets as having guided audio", %{conn: conn} do
      visible_set(%{name: "Narrated", category: "joyful"}, %{audio_url: "narrated.mp3"})
      visible_set(%{name: "Silent", category: "joyful"})

      {view, _html} = open_on(conn, 1)

      assert view |> element("#todays-sets li", "Narrated") |> render() =~ "Guided audio"
      refute view |> element("#todays-sets li", "Silent") |> render() =~ "Guided audio"
    end

    test "leave out a set with nothing in it", %{conn: conn} do
      {:ok, _} =
        Rosary.create_meditation_set(%{name: "Empty Joyful", category: "joyful"}, actor: admin())

      {view, html} = open_on(conn, 1)

      refute html =~ "Empty Joyful"
      assert html =~ "No meditation sets are available yet for these mysteries."
      refute has_element?(view, "#divine-providence")
    end

    test "Divine Providence chooses one of today's sets", %{conn: conn} do
      set = visible_set(%{name: "Only Joyful", category: "joyful"})
      visible_set(%{name: "Only Sorrowful", category: "sorrowful"})

      {view, _html} = open_on(conn, 1)
      to = "/meditation-sets/#{set.id}/pray"

      assert {:error, {:live_redirect, %{to: ^to}}} =
               view |> element("#divine-providence") |> render_click()
    end
  end

  test "offers today's Scriptural Rosary and the Rosary said aloud", %{conn: conn} do
    {view, _html} = open_on(conn, 2)

    assert has_element?(
             view,
             ~s(#todays-forms a[href="/mysteries/sorrowful/pray?form=scriptural"]),
             "The Scriptural Rosary"
           )

    assert has_element?(
             view,
             ~s(#todays-forms a[href="/mysteries/sorrowful/pray?form=holy"]),
             "The Rosary Said Aloud"
           )
  end

  test "every category is a card with its days, today's marked", %{conn: conn} do
    {view, _html} = open_on(conn, 1)

    for category <- ~w(joyful sorrowful glorious luminous seven_sorrows) do
      assert has_element?(view, ~s(#category-#{category} a[href="/mysteries/#{category}"]))
    end

    assert view |> element("#category-joyful") |> render() =~ "Today"
    refute view |> element("#category-sorrowful") |> render() =~ "Today"

    assert view |> element("#category-sorrowful") |> render() =~ "Tuesday, Friday"
    assert view |> element("#category-seven_sorrows") |> render() =~ "Mary in her grief"
  end
end
