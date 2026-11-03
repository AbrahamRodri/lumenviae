defmodule LumenViaeWeb.Live.Hours.HoursTest do
  @moduledoc """
  Hours of Prayer's public pages: `/hours` (today), `/hours/:date`,
  `/hours/:date/:hour` with its language in `?lang=`, and
  `/hours/calendar/:year/:month`. Everything is real but the wire to the
  Divinum Officium engine, which Req.Test answers with the saved pages
  the Office API's tests use, and each test has an Office cache of its own.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Office
  alias LumenViae.Office.DivinumOfficium
  alias LumenViaeWeb.Live.Hours.{CanonicalHours, DayRank, OfficeText}

  @fixtures Path.expand("../../../support/fixtures/divinum_officium", __DIR__)

  setup do
    LumenViae.Office.Cache.isolate()
    :ok
  end

  defp stub_page(name) do
    html = File.read!(Path.join(@fixtures, name))
    Req.Test.stub(DivinumOfficium, &Req.Test.html(&1, html))
  end

  defp stub_down do
    Req.Test.stub(DivinumOfficium, &Req.Test.transport_error(&1, :timeout))
  end

  describe "/hours" do
    test "opens on the hour now with Pray, the eight hours and the day's feast", %{conn: conn} do
      stub_page("kalendar_2026-08.html")
      today = Date.utc_today()

      {:ok, view, html} = live(conn, "/hours")

      assert html =~ "<h1"
      assert html =~ "Hours of Prayer"

      # Nothing is said of the hour or the day before the visitor's clock.
      assert has_element?(view, "[data-role=now-waiting]")
      refute has_element?(view, "[data-role=hour-now]")
      refute has_element?(view, "[data-role=day-date]")
      refute has_element?(view, "[data-role=now-mark]")
      render_hook(view, "set_timezone", %{"offset" => 0})
      refute has_element?(view, "[data-role=now-waiting]")

      rows = view |> render() |> Floki.parse_document!() |> Floki.find("[data-role=hour-row]")
      assert Enum.map(rows, &(Floki.attribute(&1, "data-hour") |> hd())) == CanonicalHours.slugs()

      for slug <- CanonicalHours.slugs() do
        assert has_element?(view, ~s([data-role=hour-row][href="/hours/#{today}/#{slug}"]))
      end

      present = CanonicalHours.present(NaiveDateTime.utc_now().hour)
      assert has_element?(view, ~s([data-role=pray][href="/hours/#{today}/#{present.slug}"]))
      assert has_element?(view, "[data-role=hour-now]", present.plain)
      assert has_element?(view, "[data-role=hour-now]", "Now")

      assert has_element?(
               view,
               ~s([data-role=hour-row][data-hour="#{present.slug}"][aria-current])
             )

      assert has_element?(
               view,
               ~s([data-role=calendar-link][href="/hours/calendar/#{today.year}/#{today.month}"])
             )

      render_async(view, 2000)
      assert has_element?(view, "[data-role=feast-plate]")
      refute has_element?(view, "[data-role=feast-failed]")
    end

    test "the visitor's offset moves the clock and the day", %{conn: conn} do
      stub_page("kalendar_2026-08.html")
      {:ok, view, _html} = live(conn, "/hours")

      # Fourteen hours ahead of UTC: a different hour now, perhaps tomorrow.
      local = NaiveDateTime.add(NaiveDateTime.utc_now(), 14 * 3600)
      render_hook(view, "set_timezone", %{"offset" => -14 * 60})
      present = CanonicalHours.present(local.hour)
      date = NaiveDateTime.to_date(local)

      assert has_element?(view, ~s([data-role=pray][href="/hours/#{date}/#{present.slug}"]))
      render_async(view, 2000)
      assert has_element?(view, "[data-role=feast-plate]")
    end

    test "an offset that is not one is ignored", %{conn: conn} do
      stub_page("kalendar_2026-08.html")
      {:ok, view, _html} = live(conn, "/hours")

      assert render_hook(view, "set_timezone", %{"offset" => "east"}) =~ "Hours of Prayer"
      assert render_hook(view, "set_timezone", %{"offset" => 99_999}) =~ "Hours of Prayer"
      assert render_hook(view, "set_timezone", %{}) =~ "Hours of Prayer"
    end

    test "the first view waits for the visitor's clock, so an evening is never tomorrow",
         %{conn: conn} do
      html = conn |> get("/hours") |> html_response(200)
      assert html =~ ~s(data-role="now-waiting")
      refute html =~ ~s(data-role="hour-now")
      refute html =~ ~s(data-role="day-date")

      # Nonsense never stands for a clock, and nothing is fetched meanwhile.
      stub_down()
      {:ok, view, _html} = live(conn, "/hours")
      render_hook(view, "set_timezone", %{"offset" => "x"})
      assert has_element?(view, "[data-role=now-waiting]")
      refute has_element?(view, "[data-role=feast-loading]")
      refute has_element?(view, "[data-role=feast-failed]")
    end

    test "a day fetched for the server's date is dropped once the clock moves the day",
         %{conn: conn} do
      stub_page("kalendar_2026-08.html")
      {:ok, view, _html} = live(conn, "/hours")

      # Fourteen hours ahead, then fourteen behind: the page ends on the
      # second date, whatever the first fetch answered.
      render_hook(view, "set_timezone", %{"offset" => -14 * 60})
      render_hook(view, "set_timezone", %{"offset" => 12 * 60})
      local = NaiveDateTime.add(NaiveDateTime.utc_now(), -12 * 3600)
      date = NaiveDateTime.to_date(local)

      render_async(view, 2000)
      assert has_element?(view, ~s([data-role=hour-row][href^="/hours/#{date}/"]))
      assert has_element?(view, "[data-role=day-date]", CanonicalHours.long_date(date))
    end

    test "a ?date= on today's page is ignored, not a 404", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/hours?date=foo")
      assert has_element?(view, "[data-role=now-waiting]")
    end

    test "a day missing from the month's data says nothing, and offers no Try again",
         %{conn: conn} do
      # The saved August page without its 24th.
      html =
        @fixtures
        |> Path.join("kalendar_2026-08.html")
        |> File.read!()
        |> String.replace(~r{<TR><TD[^\n]*callbrevi\('08-24-2026'\)[^\n]*</TR>}, "")

      refute html =~ "callbrevi('08-24-2026')"

      Req.Test.stub(DivinumOfficium, &Req.Test.html(&1, html))
      {:ok, view, _html} = live(conn, "/hours/1956-08-24")
      render_async(view, 2000)

      refute has_element?(view, "[data-role=feast-failed]")
      refute has_element?(view, "[data-role=retry]")
      refute has_element?(view, "[data-role=feast-loading]")
    end

    test "a fetch that raises is said as one that failed", %{conn: conn} do
      Req.Test.stub(DivinumOfficium, fn _conn -> raise "the engine broke" end)
      {:ok, view, _html} = live(conn, "/hours/1951-03-10")
      render_async(view, 2000)

      assert has_element?(view, "[data-role=feast-failed]")
    end

    test "the engine's text is escaped, never markup", %{conn: conn} do
      html =
        @fixtures
        |> Path.join("kalendar_2026-08.html")
        |> File.read!()
        |> String.replace(
          "S. Bartholomæi Apostoli",
          "&lt;script&gt;alert(1)&lt;/script&gt;"
        )

      Req.Test.stub(DivinumOfficium, &Req.Test.html(&1, html))
      {:ok, view, _html} = live(conn, "/hours/1955-08-24")
      render_async(view, 2000)

      page = render(view)
      assert page =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
      refute page =~ "<script>alert(1)"
    end

    test "an engine that cannot be reached is said quietly, and Try again tries", %{conn: conn} do
      stub_down()
      {:ok, view, _html} = live(conn, "/hours/1951-08-24")

      render_async(view, 2000)
      assert has_element?(view, "[data-role=feast-failed]", "could not be reached")
      # The hours stay links.
      assert has_element?(view, ~s([data-role=hour-row][href="/hours/1951-08-24/laudes"]))

      stub_page("kalendar_2026-08.html")
      view |> element("[data-role=retry]") |> render_click()
      render_async(view, 2000)

      assert has_element?(view, "[data-role=feast-plate]", "S. Bartholomæi Apostoli")
    end
  end

  describe "/hours/:date" do
    test "names another day, its feast and class, and offers its hours", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      {:ok, view, _html} = live(conn, "/hours/1952-08-24")
      render_hook(view, "set_timezone", %{"offset" => 0})

      assert has_element?(view, "[data-role=other-day]", "Sunday, 24 August 1952")
      refute has_element?(view, "[data-role=now-mark]")
      assert has_element?(view, ~s([data-role=today-link][href="/hours"]))
      assert has_element?(view, ~s([data-role=hour-row][href="/hours/1952-08-24/vesperae"]))

      render_async(view, 2000)
      assert has_element?(view, "[data-role=feast-plate]", "S. Bartholomæi Apostoli")
      assert has_element?(view, "[data-role=day-class]", "Feast")
      refute render(view) =~ "II. classis"
    end

    test "a date that is not one, or that the Office does not serve, is a 404", %{conn: conn} do
      for path <- ~w(/hours/tomorrow /hours/2026-02-30 /hours/1500-01-01 /hours/2300-01-01) do
        error = assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, path) end
        assert Plug.Exception.status(error) == 404
      end
    end
  end

  describe "/hours/:date/:hour" do
    test "reads the hour in English by default, with its parts and its credit", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")

      {:ok, view, html} = live(conn, "/hours/1953-08-24/laudes")

      assert html =~ ~r{<h1[^>]*>\s*Dawn Prayer}
      assert html =~ "Monday, 24 August 1953"

      render_async(view, 2000)
      text = view |> element("[data-role=office-text]") |> render()

      assert text =~ "Sing joyfully to God, all the earth"
      refute text =~ "Iubiláte Deo"
      assert text =~ "Antiphon: Greater love than this"
      refute text =~ "Ant. Greater"
      assert has_element?(view, ".hours-section__name", "Psalms")
      assert has_element?(view, "[data-role=day-line]", "Monday, 24 August 1953 · Feast")
      assert has_element?(view, "[data-role=feast]", "S. Bartholomæi Apostoli")
      assert has_element?(view, "[data-role=note]", "Psalms & antiphons from the Common or Feast")

      # The rail and the jump list name the same parts, each an anchor.
      rail = view |> render() |> Floki.parse_document!() |> Floki.find("[data-role=rail] a")
      jump = view |> render() |> Floki.parse_document!() |> Floki.find("[data-role=jump-list] a")
      assert length(rail) == 6

      assert Enum.map(rail, &String.trim(Floki.text(&1))) ==
               Enum.map(jump, &String.trim(Floki.text(&1)))

      for [href] <- Enum.map(rail, &Floki.attribute(&1, "href")) do
        assert has_element?(view, "section" <> href)
      end

      assert has_element?(view, ~s([data-role=credit][href^="https://www.divinumofficium.com/"]))
      assert has_element?(view, "[data-role=credit]", "Texts: Divinum Officium")
      assert has_element?(view, ~s([data-role=previous-hour][href="/hours/1953-08-24/matutinum"]))
      assert has_element?(view, ~s([data-role=next-hour][href="/hours/1953-08-24/prima"]))
      assert has_element?(view, ~s([data-role=back][href="/hours/1953-08-24"]))
    end

    test "?lang=latin reads the Latin alone", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")
      {:ok, view, _html} = live(conn, "/hours/1953-08-25/laudes?lang=latin")

      render_async(view, 2000)
      text = view |> element("[data-role=office-text]") |> render()

      assert text =~ "Iubiláte Deo, omnis terra"
      refute text =~ "Sing joyfully to God"
      assert has_element?(view, ".hours-section__name", "Psalmi")
      assert has_element?(view, ~s(.hours-text[lang="la"]))
      assert has_element?(view, ~s([data-role=language] a[aria-current]), "Latin")
    end

    test "?lang=both pairs the Latin with its English, line by line", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")
      {:ok, view, _html} = live(conn, "/hours/1953-08-26/laudes?lang=both")

      render_async(view, 2000)

      assert has_element?(
               view,
               ~s(.book-line--paired .book-line__primary[lang="la"]),
               "Iubiláte Deo, omnis terra"
             )

      assert has_element?(
               view,
               ".book-line--paired .book-line__secondary",
               "Sing joyfully to God, all the earth"
             )

      assert has_element?(view, ~s([data-role=language] a[aria-current]), "Both")

      assert has_element?(
               view,
               ~s([data-role=next-hour][href="/hours/1953-08-26/prima?lang=both"])
             )
    end

    test "the chooser patches the language into the link, English left out", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")
      {:ok, view, _html} = live(conn, "/hours/1953-08-27/laudes")
      render_async(view, 2000)

      view |> element("[data-role=language] a", "Both") |> render_click()
      assert_patched(view, "/hours/1953-08-27/laudes?lang=both")
      assert has_element?(view, ".book-line--paired")

      view |> element("[data-role=language] a", "English") |> render_click()
      assert_patched(view, "/hours/1953-08-27/laudes")
      refute has_element?(view, ".book-line--paired")
    end

    test "a lang that is not one is English, not a crash", %{conn: conn} do
      stub_page("laudes_2026-08-24.html")
      {:ok, view, _html} = live(conn, "/hours/1953-08-28/laudes?lang[x]=1")
      render_async(view, 2000)

      assert has_element?(view, ~s([data-role=language] a[aria-current]), "English")
    end

    test "Matins has no hour before it and Compline none after", %{conn: conn} do
      stub_page("matutinum_2026-08-24.html")
      {:ok, view, _html} = live(conn, "/hours/1953-08-29/matutinum")
      render_async(view, 2000)

      refute has_element?(view, "[data-role=previous-hour]")
      assert has_element?(view, "[data-role=next-hour]", "Dawn Prayer")
    end

    test "an engine that cannot be reached is said, with Try again", %{conn: conn} do
      stub_down()
      {:ok, view, _html} = live(conn, "/hours/1953-08-30/vesperae")
      render_async(view, 2000)

      assert has_element?(view, "[data-role=hour-failed]", "Evening Prayer could not be reached")

      stub_page("vesperae_2026-08-24.html")
      view |> element("[data-role=retry]") |> render_click()
      render_async(view, 2000)

      refute has_element?(view, "[data-role=hour-failed]")
      assert has_element?(view, "[data-role=office-text]")
    end

    test "an unknown hour or a bad date is a 404", %{conn: conn} do
      for path <-
            ~w(/hours/1953-08-24/midnight /hours/1953-08-24/Laudes /hours/24-08-1953/laudes /hours/1599-12-31/laudes) do
        error = assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, path) end
        assert Plug.Exception.status(error) == 404
      end
    end
  end

  describe "/hours/calendar/:year/:month" do
    test "draws the month by the days' classes, each day a link", %{conn: conn} do
      stub_page("kalendar_2026-08.html")

      {:ok, view, html} = live(conn, "/hours/calendar/1954/8")

      assert html =~ ~r{<h1[^>]*>\s*August 1954}
      cells = html |> Floki.parse_document!() |> Floki.find("[data-role=day-cell]")
      assert length(cells) == 31
      assert has_element?(view, ~s([data-role=day-cell][href="/hours/1954-08-24"]))
      assert has_element?(view, ~s([data-role=previous-month][href="/hours/calendar/1954/7"]))
      assert has_element?(view, ~s([data-role=next-month][href="/hours/calendar/1954/9"]))

      render_async(view, 2000)
      day = view |> element(~s([data-role=day-cell][data-date="1954-08-24"])) |> render()

      assert day =~ "S. Bartholomæi Apostoli"
      assert day =~ "hours-day__mark--second"
    end

    test "the arrows step the month in place", %{conn: conn} do
      stub_page("kalendar_2026-08.html")
      {:ok, view, _html} = live(conn, "/hours/calendar/1954/8")

      view |> element("[data-role=next-month]") |> render_click()
      assert_patched(view, "/hours/calendar/1954/9")
      assert has_element?(view, "h1", "September 1954")
      render_async(view, 2000)
      assert has_element?(view, ~s([data-role=day-cell][data-date="1954-09-30"]))
    end

    test "today is marked by the visitor's date, never the server's", %{conn: conn} do
      stub_page("kalendar_2026-08.html")
      today = Date.utc_today()
      {:ok, view, _html} = live(conn, "/hours/calendar/#{today.year}/#{today.month}")

      refute has_element?(view, "[data-role=day-cell][aria-current]")
      render_hook(view, "set_timezone", %{"offset" => 0})

      assert has_element?(
               view,
               ~s([data-role=day-cell][aria-current="date"][data-date="#{today}"])
             )
    end

    test "a month that cannot be reached still links every day", %{conn: conn} do
      stub_down()
      {:ok, view, _html} = live(conn, "/hours/calendar/1954/10")
      render_async(view, 2000)

      assert has_element?(view, "[data-role=calendar-failed]", "could not be reached")
      assert has_element?(view, ~s([data-role=day-cell][href="/hours/1954-10-31"]))
    end

    test "a month that is not one is a 404", %{conn: conn} do
      for path <-
            ~w(/hours/calendar/1954/13 /hours/calendar/1954/0 /hours/calendar/abc/1 /hours/calendar/1500/1 /hours/calendar/99999999999/1) do
        error = assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, path) end
        assert Plug.Exception.status(error) == 404
      end
    end
  end

  describe "the header" do
    test "links Hours after Consecration, Prayers and Chant, then Explore, and marks it on every Hours page",
         %{
           conn: conn
         } do
      stub_page("laudes_2026-08-24.html")
      html = conn |> get("/hours/1953-08-24/laudes") |> html_response(200)
      doc = Floki.parse_document!(html)

      labels =
        doc |> Floki.find("#site-header nav[aria-label=Main] > a") |> Enum.map(&Floki.text/1)

      labels = Enum.map(labels, &String.trim/1)

      assert Enum.drop_while(labels, &(&1 != "Consecration")) |> Enum.take(5) == [
               "Consecration",
               "Prayers",
               "Chant",
               "Hours",
               "Explore"
             ]

      assert [_desktop, _phone] = Floki.find(doc, ~s(a[href="/hours"][aria-current=page]))
    end
  end

  describe "the Missal behind a day (W4)" do
    test "is reached only through the suite's stub, never the network", %{conn: conn} do
      stub_page("kalendar_2026-08.html")
      calls = :counters.new(1, [])

      Req.Test.stub(LumenViae.Office.MissaleMeum, fn conn ->
        :counters.add(calls, 1, 1)
        Req.Test.transport_error(conn, :econnrefused)
      end)

      {:ok, view, _html} = live(conn, "/hours/2026-08-27")
      render_async(view, 2000)
      assert :counters.get(calls, 1) == 1
      # Without the Missal the day keeps the Office's Latin title.
      assert has_element?(view, "[data-role=feast-plate] [lang=la]")
    end
  end

  describe "the sitemap and robots.txt" do
    test "list /hours and keep crawlers out of the dated pages" do
      sitemap = File.read!(Application.app_dir(:lumen_viae, "priv/static/sitemap.xml"))
      robots = File.read!(Application.app_dir(:lumen_viae, "priv/static/robots.txt"))

      assert sitemap =~ "<loc>https://www.lumenviae.org/hours</loc>"
      refute sitemap =~ "/hours/"
      assert robots =~ "Disallow: /hours/\n"
    end
  end

  describe "the hours and the day's class" do
    test "the eight hours are the Office's own, in its order" do
      assert CanonicalHours.slugs() == Enum.map(Office.vocabulary().hours, & &1.slug)
    end

    test "the hour now and when it lapses, from the clock" do
      assert CanonicalHours.present(0).slug == "matutinum"
      assert CanonicalHours.present(4).slug == "matutinum"
      assert CanonicalHours.present(5).slug == "laudes"
      assert CanonicalHours.present(11).slug == "tertia"
      assert CanonicalHours.present(23).slug == "completorium"
      assert CanonicalHours.lapses(CanonicalHours.fetch("tertia")) == "until noon"
      assert CanonicalHours.lapses(CanonicalHours.fetch("completorium")) == "until midnight"
      assert CanonicalHours.lapses(CanonicalHours.fetch("nona")) == "until four"
    end

    test "the engine's Latin class in plain words" do
      assert DayRank.plain("I. classis", "In Nativitate Domini") == "Great Feast"
      assert DayRank.plain("II. classis", "S. Bartholomæi Apostoli") == "Feast"
      assert DayRank.plain("III. classis", "S. Dominici Confessoris") == "Lesser Feast"
      assert DayRank.plain("IV. classis", "Sanctæ Mariæ Sabbato") == "Weekday"

      assert DayRank.plain("III. classis", "Feria Quarta", "Hebdomada I Quadragesimæ") ==
               "Lenten Weekday"

      assert DayRank.plain(nil, "Feria II infra Hebdomadam I Adventus") == "Advent Weekday"
      assert DayRank.plain("I. classis", "In Octava Nativitatis") == "Great Feast"
      assert DayRank.mark(nil) == nil
      assert DayRank.mark("I. classis") == :first
    end

    # The calendar's own titles, ranks and season lines, as
    # /api/office/calendar answered them for these months, and the class
    # the iOS app says for each day.
    @season_days [
      # Advent, December 2026
      {"Feria III infra Hebd I Adventus", "III. classis", nil, "Advent Weekday"},
      {"S. Bibianæ Virginis et Martyris", "III. classis", "Feria IV infra Hebd I Adventus",
       "Lesser Feast"},
      {"Sabbato infra Hebd I Adventus", "III. classis", "S. Sabbæ Abbatis", "Advent Weekday"},
      {"Dominica II Adventus", "I. classis", nil, "Great Feast"},
      {"In Conceptione Immaculata Beatæ Mariæ Virginis", "I. classis",
       "Feria III infra Hebd II Adventus", "Great Feast"},
      {"Feria IV Quattuor Temporum Adventus", "II. classis", "S. Eusebii Episcopi et Martyris",
       "Advent Weekday"},
      {"Feria V infra Hebd III Adventus", "II. classis", nil, "Advent Weekday"},
      {"Sabbato Quattuor Temporum Adventus", "II. classis", nil, "Advent Weekday"},
      {"In Vigilia Nativitatis Domini", "I. classis", "Feria V infra Hebd IV Adventus",
       "Great Feast"},
      {"In Nativitate Domini", "I. classis", nil, "Great Feast"},
      {"Diei V infra Octavam Nativitatis", "II. classis", nil, "Feast"},
      # Lent, February to March 2027
      {"Feria IV Cinerum", "I. classis", nil, "Lenten Weekday"},
      {"Sabbato post Cineres", "III. classis", nil, "Lenten Weekday"},
      {"Feria Quarta Quattuor Temporum Quadragesimæ", "II. classis", nil, "Lenten Weekday"},
      {"Feria Secunda infra Hebd III in Quadr", "III. classis", nil, "Lenten Weekday"},
      {"Feria Secunda infra Hebdomadam III in Quadragesima", "III. classis", nil,
       "Lenten Weekday"},
      {"Sabbato infra Hebd III in Quadr", "III. classis", "Ss. Perpetuæ et Felicitatis Martyrum",
       "Lenten Weekday"},
      {"Dominica IV in Quadr", "I. classis", nil, "Great Feast"},
      {"Feria Tertia infra Hebd Passionis", "III. classis", nil, "Lenten Weekday"},
      {"Sabbato infra Hebd Passionis", "III. classis", nil, "Lenten Weekday"},
      {"S. Joseph Sponsi B.M.V. Confessoris", "I. classis", "Feria Sexta infra Hebd Passionis",
       "Great Feast"},
      # Holy Week and the Easter Octave, March and April 2027
      {"Dominica II Passionis seu in Palmis", "I. classis", nil, "Great Feast"},
      {"Feria Secunda Hebdomadæ Sanctæ", "I. classis", nil, "Lenten Weekday"},
      {"Feria Quarta Hebdomadæ Sanctæ", "I. classis", nil, "Lenten Weekday"},
      {"Feria Quinta in Cena Domini", "I. classis", "In Annuntiatione Beatæ Mariæ Virginis",
       "Great Feast"},
      {"Feria Sexta in Passione et Morte Domini", "I. classis", nil, "Great Feast"},
      {"Sabbato Sancto", "I. classis", nil, "Great Feast"},
      {"Dominica Resurrectionis", "I. classis", nil, "Great Feast"},
      {"Die II infra octavam Paschæ", "Dies Octavæ I. classis", nil, nil},
      {"Sabbato in Albis", "Dies Octavæ I. classis", nil, nil},
      {"Dominica in Albis in Octava Paschæ", "I. classis", nil, "Great Feast"},
      {"Feria Tertia infra Hebd I post Octavam Paschæ", "IV. classis", nil, "Weekday"},
      {"Sanctæ Mariæ Sabbato", "IV. classis", nil, "Weekday"},
      {"S. Hermenegildi Martyris", "III. classis",
       "Feria Tertia infra Hebd II post Octavam Paschæ", "Lesser Feast"},
      # Pentecost's octave, May 2027, and an Ember day of September 2026
      {"Feria Quarta Quattuor Temporum Pentecostes", "Dies Octavæ I. classis", nil, nil},
      {"Feria Quarta Quattuor Temporum Septembris", "II. classis", nil, "Weekday"}
    ]

    test "the class in plain words through Advent, Lent, Holy Week and Easter, as iOS says it" do
      for {title, rank, season, plain} <- @season_days do
        assert {title, DayRank.plain(rank, title, season)} == {title, plain}
      end
    end

    test "a Lent day says the same on /hours, the calendar and its hour page" do
      calendar = %{
        celebration: %{title: "Feria Secunda infra Hebd III in Quadr", rank: "III. classis"},
        detail: nil
      }

      hour = %{
        celebration: %{
          title: "Feria Secunda infra Hebdomadam III in Quadragesima",
          rank: "III. classis"
        },
        tempora: nil
      }

      assert DayRank.plain_for(calendar) == "Lenten Weekday"
      assert DayRank.plain_for(hour) == "Lenten Weekday"
    end

    test "an hour's lines are cleaned as the app cleans them" do
      assert OfficeText.normalized("Ant. Hoc est.", :latin) == "Antiphon: Hoc est."
      assert OfficeText.normalized("S. Dominus vobiscum.", :latin) == "P. Dominus vobiscum."
      assert OfficeText.normalized("M. Et cum spiritu tuo.", :latin) == "S. Et cum spiritu tuo."
      assert OfficeText.normalized("S. Joánnis Baptístæ", :latin) == "S. Joánnis Baptístæ"

      assert OfficeText.normalized("S. And with thy spirit.", :english) ==
               "S. And with thy spirit."

      assert OfficeText.normalized("Deus + in adiutórium", :latin) == "Deus ✠ in adiutórium"
    end

    test "a rubric in braces is a note, out of its braces" do
      section = %{latin: %{title: nil, note: nil, lines: ["Incipit{omittitur}"]}, vernacular: nil}

      assert [%{body: {:single, :latin, [[{:text, "Incipit"}, {:note, "omittitur"}]]}}] =
               OfficeText.sections([section], "latin")
    end

    test "sides that do not pair line for line stand as two blocks" do
      section = %{
        latin: %{title: "Hymnus", note: nil, lines: ["Una", "Duo"]},
        vernacular: %{title: "Hymn", note: nil, lines: ["One"]}
      }

      assert [%{body: {:blocks, [_, _], [_]}, name: "Hymn"}] =
               OfficeText.sections([section], "both")

      assert [%{body: {:single, :latin, [_, _]}, name: "Hymnus"}] =
               OfficeText.sections([section], "latin")
    end
  end
end
