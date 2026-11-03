defmodule LumenViaeWeb.Live.Consecration.ConsecrationTest do
  @moduledoc """
  The Consecration on the website: `/consecration` (the introduction, the
  feast chooser, the waiting page, on to today's day), a day's page and
  its flow at `/consecration/days/:n?step=`, the Act made at
  `/consecration/act`, the 404s, the header and the sitemap. The plan is
  the browser's, handed over by the `ConsecrationPlan` hook, so each test
  hands it over with `render_hook/3`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Consecration.Days

  defp today, do: Date.utc_today()

  defp state(plan, done \\ [], today \\ Date.utc_today()) do
    %{"plan" => plan, "done" => done, "intro_seen" => false, "today" => Date.to_iso8601(today)}
  end

  describe "/consecration" do
    test "opens on the welcome, still until the browser speaks", %{conn: conn} do
      {:ok, view, html} = live(conn, "/consecration")

      assert view |> element("h1") |> render() =~ "Consecration to Mary"
      assert html =~ "33 days with Mary"
      assert has_element?(view, "[data-role=stage][data-known=false]")

      render_hook(view, "consecration_state", state(nil))
      assert has_element?(view, "[data-role=stage][data-known=true]")
      assert has_element?(view, "[data-role=intro-welcome]")
    end

    test "walks the introduction's pages to the chooser", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration?step=devotion")
      assert view |> element("h1") |> render() =~ "Everything you are"

      {:ok, view, html} = live(conn, "/consecration?step=day")
      assert view |> element("h1") |> render() =~ "The same three steps each day"
      assert html =~ "Come, Creator Spirit"
      assert html =~ "One question to sit with."
      refute html =~ "journal"

      {:ok, view, html} = live(conn, "/consecration?step=journey")
      assert view |> element("h1") |> render() =~ "The Path to Consecration"
      assert html =~ "Knowing Mary"

      {:ok, view, _html} = live(conn, "/consecration?step=choose")
      assert view |> element("h1") |> render() =~ "Choose your feast"
      refute has_element?(view, "[data-role=intro-skip]")
    end

    test "an unknown step is the welcome", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration?step=nope")
      assert has_element?(view, "[data-role=intro-welcome]")

      {:ok, view, _html} = live(conn, "/consecration?step[]=x")
      assert has_element?(view, "[data-role=intro-welcome]")
    end

    test "a returning visitor opens on the chooser", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration")
      render_hook(view, "consecration_state", %{state(nil) | "intro_seen" => true})
      assert has_element?(view, "[data-role=chooser]")
    end

    test "the chooser offers the soonest feast and begins it in this browser", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration?step=choose")
      render_hook(view, "consecration_state", state(nil, [], ~D[2026-11-02]))

      assert view |> element("[data-role=chosen-feast]") |> render() =~ "Immaculate Conception"
      assert view |> element("[data-role=day-one]") |> render() =~ "Thursday, November 5"

      begin = view |> element("[data-role=begin]") |> render()
      assert begin =~ ~s(data-start="2026-11-05")
      assert begin =~ ~s(data-feast="immaculate_conception")
      assert begin =~ "Begin on November 5"

      assert length(
               view
               |> render()
               |> Floki.parse_document!()
               |> Floki.find("[data-role=feast-row]")
             ) ==
               3

      view |> element("[data-role=more-feasts]") |> render_click()

      assert view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("[data-role=feast-row]")
             |> length() == 8

      view |> element("[data-role=feast-row]", "Our Lady of Guadalupe") |> render_click()
      assert view |> element("[data-role=chosen-feast]") |> render() =~ "Guadalupe"
      assert view |> element("[data-role=begin]") |> render() =~ ~s(data-start="2026-11-09")
    end

    test "Start at any day begins today at the day chosen", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration?step=choose")
      render_hook(view, "consecration_state", state(nil, [], ~D[2026-11-02]))

      view |> element("[data-role=any-start]") |> render_click()
      view |> element("#cons-any-form") |> render_change(%{"day" => "15"})

      assert view |> element("[data-role=any-begin]") |> render() =~ ~s(data-start="2026-10-19")
      assert view |> element("[data-role=any-date]") |> render() =~ "November 21, 2026"

      view |> element("#cons-any-form") |> render_change(%{"day" => "x"})
      assert view |> element("[data-role=any-begin]") |> render() =~ "Begin today at Day 1"
    end

    test "a plan before its Day 1 waits on its own page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration")

      render_hook(
        view,
        "consecration_state",
        state(
          %{"start" => "2026-11-05", "feast_id" => "immaculate_conception"},
          [],
          ~D[2026-11-02]
        )
      )

      assert has_element?(view, "[data-role=scheduled]")
      assert view |> element("h1") |> render() =~ "Your 33 days begin Thursday, November 5"
      assert view |> element("[data-role=feast-name]") |> render() =~ "Immaculate Conception"
      assert has_element?(view, ~s([data-role=read-book][href="/true-devotion"]))
      assert has_element?(view, "[data-role=another-feast][data-consecration-restart]")
    end

    test "a plan under way goes on to today's day", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration")
      start = Date.add(today(), -4)

      assert {:error, {:live_redirect, %{to: "/consecration/days/5"}}} =
               render_hook(
                 view,
                 "consecration_state",
                 state(%{"start" => Date.to_iso8601(start)})
               )
    end

    test "a finished plan offers the feasts again, honouring it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration")

      render_hook(
        view,
        "consecration_state",
        state(%{"start" => "2026-01-01", "completed_at" => "2026-02-03T08:00:00Z"})
        |> Map.put("intro_seen", true)
      )

      assert view |> element("[data-role=completed-note]") |> render() =~
               "Consecration completed — renew whenever you wish"
    end

    test "a finished plan's note names the day it was made", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration")

      render_hook(
        view,
        "consecration_state",
        state(%{"start" => "2026-01-01", "completed_at" => "2026-02-03T08:00:00Z"})
        |> Map.merge(%{"completed_on" => "2026-02-03", "intro_seen" => true})
      )

      assert view |> element("[data-role=completed-note]") |> render() =~
               "Consecrated February 3, 2026 — renew whenever you wish"
    end

    test "nonsense from the browser is no plan", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration")

      assert render_hook(view, "consecration_state", %{"plan" => [1], "done" => "x", "today" => 5}) =~
               "Consecration to Mary"

      assert render_hook(view, "consecration_state", %{}) =~ "Consecration to Mary"
      assert render_hook(view, "select_feast", %{"id" => ["x"]}) =~ "Consecration to Mary"
    end
  end

  describe "/consecration/days/:n" do
    test "a day's page: its badge, title, prayers, readings and question", %{conn: conn} do
      {:ok, view, html} = live(conn, "/consecration/days/1")

      assert view |> element("h1") |> render() =~ "The Spirit of the World"
      assert view |> element("[data-role=badge]") |> render() =~ "Day 1 of 33"
      assert view |> element("[data-role=pray]") |> render() =~ "Open day 1"

      rows = html |> Floki.parse_document!() |> Floki.find("[data-role=prayer-row]")
      assert length(rows) == 4
      assert rows |> Enum.at(1) |> Floki.attribute("href") == ["/consecration/days/1?step=2"]

      readings = html |> Floki.parse_document!() |> Floki.find("[data-role=reading-row]")
      assert readings |> hd() |> Floki.attribute("href") == ["/consecration/days/1?step=5"]
      assert html =~ "Matthew 5:1-19"
      assert view |> element("[data-role=reflection]") |> render() =~ "worldly attachments"
      refute has_element?(view, "[data-role=restart]")
      assert has_element?(view, ~s([data-role=book][href="/true-devotion"]))
    end

    test "Consecration Day is day 34", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration/days/34")
      assert view |> element("[data-role=badge]") |> render() =~ "Consecration Day"
    end

    test "marks today and the days prayed from the browser's plan", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration/days/3")
      start = Date.add(today(), -2)
      render_hook(view, "consecration_state", state(%{"start" => Date.to_iso8601(start)}, [1, 2]))

      assert view |> element("[data-role=pray]") |> render() =~ "Begin today&#39;s prayer"
      assert view |> element(".cons-day-dot.is-done", "1") |> has_element?()
      assert view |> element(".cons-day-dot.is-today", "3") |> has_element?()
      assert view |> element("[data-role=journey]") |> render() =~ "2 of 33 prayed"
      assert has_element?(view, "[data-role=restart]")
      assert has_element?(view, "[data-role=feast-line]")

      render_hook(
        view,
        "consecration_state",
        state(%{"start" => Date.to_iso8601(start)}, [1, 2, 3])
      )

      assert view |> element("[data-role=pray]") |> render() =~ "Pray it again"
    end

    test "the journey shows another stage on its road", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration/days/1")

      view
      |> element("[data-role=road-segment][phx-value-id=knowledge_of_mary]")
      |> render_click()

      assert view |> element("[data-role=shown-stage]") |> render() =~ "Week 2"
      assert has_element?(view, ~s([data-role=day-dot][href="/consecration/days/20"]))
      assert render_hook(view, "show_phase", %{"id" => "nope"}) =~ "Week 2"
    end

    test "the prayers' language rides in the link", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration/days/1?lang=latin")

      assert view |> element("[data-role=prayer-row]", "Veni Creator") |> render() =~
               "/consecration/days/1?step=1&amp;lang=latin"
    end

    test "a day that is not one is a 404", %{conn: conn} do
      for n <- ~w(0 35 2.5 x -1 01x) do
        error =
          assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/consecration/days/#{n}") end

        assert Plug.Exception.status(error) == 404
      end
    end
  end

  describe "a day stepped through" do
    test "a prayer a page, its chant and its Latin", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration/days/1?step=1")

      assert view |> element("[data-role=step-title]") |> render() =~ "Come, Creator Spirit"
      assert view |> element("[data-role=second-title]") |> render() =~ "Veni Creator"
      assert view |> element("[data-role=step-count]") |> render() =~ "1 of 6"
      assert has_element?(view, "[data-role=chant][phx-hook=ChantGuest] audio[src]")
      assert has_element?(view, "#consecration-day[data-layout=focused]")
      refute has_element?(view, "[data-role=previous]")
      assert view |> element("[data-role=next]") |> render() =~ "Hail, Star of the Sea"

      {:ok, view, _html} = live(conn, "/consecration/days/1?step=1&lang=both")
      assert view |> render() =~ "Creátor Spíritus"
    end

    test "after the last prayer, the readings, then Amen", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration/days/1?step=4")
      assert view |> element("[data-role=next]") |> render() =~ "Go to the readings"

      {:ok, view, _html} = live(conn, "/consecration/days/1?step=5")
      assert view |> element("[data-role=reading-title]") |> render() =~ "Matthew 5:1-19"

      assert view |> element("[data-role=reading-text]") |> render() =~
               "Blessed are the poor in spirit"

      {:ok, view, _html} = live(conn, "/consecration/days/1?step=6")
      amen = view |> element("[data-role=amen]") |> render()
      assert amen =~ ~s(href="/consecration/days/1")
      assert amen =~ "data-consecration-amen"
      assert amen =~ ~s(data-day="1")
    end

    test "a reading's own title is set as a title", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration/days/15?step=4")
      text = view |> element("[data-role=reading-text]") |> render()

      assert text =~ ~s(<h2 class="cons-reading-text__heading">Examples inviting Repentance</h2>)
      refute text =~ "# Examples"
    end

    test "Consecration Day's Amen goes on to the Act made", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration/days/34?step=99")
      assert view |> element("[data-role=amen]") |> render() =~ ~s(href="/consecration/act")
    end

    test "under a plan, Amen returns to today's day; a day ahead keeps to itself", %{conn: conn} do
      plan = state(%{"start" => Date.to_iso8601(Date.add(today(), -4))})

      {:ok, view, _html} = live(conn, "/consecration/days/2?step=99")
      render_hook(view, "consecration_state", plan)
      assert has_element?(view, ~s([data-role=amen][href="/consecration/days/5"]))

      {:ok, view, _html} = live(conn, "/consecration/days/9?step=99&lang=latin")
      render_hook(view, "consecration_state", plan)
      assert has_element?(view, ~s([data-role=amen][href="/consecration/days/9?lang=latin"]))

      {:ok, view, _html} = live(conn, "/consecration/days/34?step=99")
      render_hook(view, "consecration_state", plan)
      assert has_element?(view, ~s([data-role=amen][href="/consecration/days/34"]))
    end

    test "Consecration Day's Amen goes on to the Act when it is today", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration/days/34?step=99")

      render_hook(
        view,
        "consecration_state",
        state(%{"start" => Date.to_iso8601(Date.add(today(), -40))})
      )

      assert has_element?(view, ~s([data-role=amen][href="/consecration/act"]))
    end

    test "a step past either end is the nearest, anything else the first", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration/days/1?step=99")
      assert view |> element("[data-role=step-count]") |> render() =~ "6 of 6"

      for step <- ~w(0 x 2.5) do
        {:ok, view, _html} = live(conn, "/consecration/days/1?step=#{step}")
        assert view |> element("[data-role=step-count]") |> render() =~ "1 of 6"
      end

      {:ok, view, _html} = live(conn, "/consecration/days/1?step[]=3&lang[]=x")
      assert view |> element("[data-role=step-count]") |> render() =~ "1 of 6"
    end
  end

  describe "Restart" do
    test "from a day's page returns to the Consecration", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/consecration/days/3")

      assert {:error, {:live_redirect, %{to: "/consecration"}}} =
               render_hook(view, "consecration_state", Map.put(state(nil), "restarted", true))
    end
  end

  describe "/consecration/act" do
    test "the Act made, with its words and the way back", %{conn: conn} do
      {:ok, view, html} = live(conn, "/consecration/act")

      assert view |> element("h1") |> render() =~ "I am all yours"
      assert html =~ "Totus tuus ego sum"
      assert html =~ "O Eternal and Incarnate Wisdom!"
      assert has_element?(view, ~s([data-role=return][href="/consecration"]))
      assert has_element?(view, ~s([data-role=book-act][href="/true-devotion/formula"]))
      refute has_element?(view, "[data-role=restart]")

      render_hook(view, "consecration_state", state(%{"start" => "2026-01-01"}))
      assert has_element?(view, "[data-role=restart][data-consecration-restart]")
    end
  end

  describe "the header" do
    test "links Consecration before Prayers and marks it on every Consecration page", %{
      conn: conn
    } do
      html = conn |> get("/consecration/days/4") |> html_response(200)
      doc = Floki.parse_document!(html)

      labels =
        doc
        |> Floki.find("#site-header nav[aria-label=Main] > a")
        |> Enum.map(&(&1 |> Floki.text() |> String.trim()))

      assert Enum.drop_while(labels, &(&1 != "Consecration")) |> Enum.take(2) == [
               "Consecration",
               "Prayers"
             ]

      assert [_desktop, _phone] = Floki.find(doc, ~s(a[href="/consecration"][aria-current=page]))
    end
  end

  describe "the sitemap" do
    test "lists the Consecration, the Act and every day" do
      sitemap = File.read!(Application.app_dir(:lumen_viae, "priv/static/sitemap.xml"))

      assert sitemap =~ "<loc>https://www.lumenviae.org/consecration</loc>"
      assert sitemap =~ "<loc>https://www.lumenviae.org/consecration/act</loc>"

      for n <- 1..34 do
        assert sitemap =~ "<loc>https://www.lumenviae.org#{Days.day_path(n)}</loc>"
      end
    end
  end
end
