defmodule LumenViaeWeb.Live.Missal.MissalTest do
  @moduledoc """
  The Daily Missal's public pages: `/missal` (today), `/missal/:date`
  with `?lang=` and `?mass=`, `/missal/order-of-mass` and
  `/missal/calendar/:year/:month`; Today's Mass on Hours of Prayer's
  landing; the sitemap and robots.txt. Everything is real but the wire to
  Missale Meum, which Req.Test answers with saved answers, and each test
  has an Office cache of its own.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Office.MissaleMeum
  alias LumenViaeWeb.Live.Missal.{Days, MissalText}

  @moduletag :capture_log

  @fixtures Path.expand("../../../support/fixtures/missale_meum", __DIR__)

  setup do
    LumenViae.Office.Cache.isolate()
    :ok
  end

  defp fixture(name), do: File.read!(Path.join(@fixtures, name))

  # Missale Meum as the saved answers have it: All Souls and St. Charles
  # Borromeo by their dates, St. Charles's Mass for any other day.
  defp stub_missal(overrides \\ %{}) do
    Req.Test.stub(MissaleMeum, fn conn ->
      body =
        case conn.request_path do
          "/en/api/v5/proper/" <> date ->
            Map.get(overrides, date) ||
              if date == "2026-11-02",
                do: fixture("proper_2026-11-02.json"),
                else: fixture("proper_2026-11-04.json")

          "/en/api/v5/calendar/" <> _year ->
            fixture("calendar_2026.json")

          "/en/api/v5/ordo" ->
            fixture("ordo.json")
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, body)
    end)
  end

  defp stub_down do
    Req.Test.stub(MissaleMeum, &Req.Test.transport_error(&1, :econnrefused))
  end

  describe "/missal" do
    test "waits for the visitor's clock, then shows today's Mass", %{conn: conn} do
      html = conn |> get("/missal") |> html_response(200)
      assert html =~ ~s(data-role="plate-waiting")
      refute html =~ ~s(data-role="date-pill")

      stub_missal()
      {:ok, view, _html} = live(conn, "/missal")
      assert has_element?(view, "[data-role=plate-waiting]")
      refute has_element?(view, "[data-role=mass-loading]")

      render_hook(view, "set_timezone", %{"offset" => 0})
      today = Date.utc_today()
      assert has_element?(view, "[data-role=date-pill]", Days.pill_date(today))

      assert has_element?(
               view,
               ~s([data-role=date-pill][href="/missal/calendar/#{today.year}/#{today.month}"])
             )

      render_async(view, 2000)
      assert has_element?(view, "[data-role=feast]")
      refute has_element?(view, "[data-role=today-link]")

      assert has_element?(
               view,
               ~s([data-role=previous-day][href="/missal/#{Date.add(today, -1)}"])
             )

      assert has_element?(view, ~s([data-role=next-day][href="/missal/#{Date.add(today, 1)}"]))
    end

    test "the visitor's offset moves the day", %{conn: conn} do
      stub_missal()
      {:ok, view, _html} = live(conn, "/missal")

      local = NaiveDateTime.add(NaiveDateTime.utc_now(), 14 * 3600)
      render_hook(view, "set_timezone", %{"offset" => -14 * 60})
      date = NaiveDateTime.to_date(local)

      assert has_element?(view, "[data-role=date-pill]", Days.pill_date(date))
    end

    test "an offset that is not one is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/missal")
      render_hook(view, "set_timezone", %{"offset" => "east"})
      render_hook(view, "set_timezone", %{})
      assert has_element?(view, "[data-role=plate-waiting]")
    end
  end

  describe "/missal/:date" do
    test "the feast, its class and vestment, and the parts of the Mass", %{conn: conn} do
      stub_missal()
      {:ok, view, html} = live(conn, "/missal/2026-11-04")

      assert html =~ "<h1"
      render_async(view, 2000)

      assert has_element?(view, "[data-role=feast]", "St. Charles Borromeo")

      assert has_element?(
               view,
               "[data-role=remembered]",
               "Also remembered today: Sts. Vitalis and Agricola, Martyrs"
             )

      assert has_element?(view, "[data-role=day-class]", "Lesser Feast")

      assert has_element?(
               view,
               "[data-role=day-class][aria-label='Lesser Feast, white vestments']"
             )

      assert has_element?(view, "[data-role=vestment][data-vestment=White]")

      # The parts in the rail, plainly named, the first the Entrance Chant.
      assert has_element?(view, "[data-role=rail] a", "Entrance Chant")
      assert has_element?(view, "[data-role=rail] a", "Prayer over the Gifts · Also Remembered")
      assert has_element?(view, "[data-role=jump-list]")

      # Each part: its posture, the propers' diamond, the Latin name beside.
      assert has_element?(view, "[data-role=missal-section] [data-role=posture]", "Stand")
      assert has_element?(view, "[data-role=missal-section] .missal-section__latin", "Introitus")
      assert has_element?(view, "[data-role=missal-section] [data-role=proper]")
      assert has_element?(view, "[data-role=citation]")
      assert has_element?(view, ".missal-line--versal")

      assert has_element?(view, ~s([data-role=ordo-link][href="/missal/order-of-mass"]))
      assert has_element?(view, "[data-role=credit]", "texts from Missale Meum")
      refute has_element?(view, "[data-role=masses]")
      refute has_element?(view, "[data-role=about]")
    end

    test "a day of three Masses offers each, and ?mass= chooses", %{conn: conn} do
      stub_missal()
      {:ok, view, _html} = live(conn, "/missal/2026-11-02")
      render_async(view, 2000)

      assert has_element?(view, "[data-role=masses]", "3 Masses today · choose one")
      assert has_element?(view, "[data-role=feast]", "Commemoration of All Souls")
      assert has_element?(view, "[data-role=day-class]", "Great Feast")

      view |> element("[data-role=mass-choice]", "Second Mass") |> render_click()
      assert_patch(view, "/missal/2026-11-02?mass=2")
      assert has_element?(view, "[data-role=feast]", "Second Mass")
      assert has_element?(view, "[data-role=mass-choice][aria-current]", "Second Mass")
    end

    test "?lang=latin reads the Latin, ?lang=both pairs it with the English", %{conn: conn} do
      stub_missal()
      {:ok, view, _html} = live(conn, "/missal/2026-11-04?lang=latin")
      render_async(view, 2000)
      text = view |> element("[data-role=missal-text]") |> render()
      assert text =~ "Státuit ei Dóminus"
      refute text =~ "The Lord made a covenant"

      {:ok, view, _html} = live(conn, "/missal/2026-11-04?lang=both")
      render_async(view, 2000)
      assert has_element?(view, "[data-role=paired] .book-line__primary[lang=la]")
      assert has_element?(view, "[data-role=paired] .book-line__secondary[lang=en]")
    end

    test "the chooser patches the language into the link, English left out", %{conn: conn} do
      stub_missal()
      {:ok, view, _html} = live(conn, "/missal/2026-11-04")
      render_async(view, 2000)

      view |> element("[data-role=language] a", "Both") |> render_click()
      assert_patch(view, "/missal/2026-11-04?lang=both")
      view |> element("[data-role=language] a", "English") |> render_click()
      assert_patch(view, "/missal/2026-11-04")
    end

    test "About this day, when Missale Meum says something of it", %{conn: conn} do
      day =
        Jason.encode!([
          %{
            "info" => %{
              "id" => "x",
              "title" => "St. Test",
              "description" => "A word on the day.\n\nAnd another.",
              "rank" => 2,
              "colors" => ["r"]
            },
            "sections" => [%{"id" => "Introitus", "label" => "Introit", "body" => [["In", "La"]]}]
          }
        ])

      stub_missal(%{"2026-11-05" => day})
      {:ok, view, _html} = live(conn, "/missal/2026-11-05")
      render_async(view, 2000)

      assert has_element?(view, "[data-role=about] p", "A word on the day.")
      assert has_element?(view, "[data-role=about] p", "And another.")
      assert has_element?(view, "[data-role=vestment][data-vestment=Red]")
    end

    test "Return to today, once today is known to be another day", %{conn: conn} do
      stub_missal()
      {:ok, view, _html} = live(conn, "/missal/2026-11-04")
      refute has_element?(view, "[data-role=today-link]")
      render_hook(view, "set_timezone", %{"offset" => 0})

      if Date.utc_today() == ~D[2026-11-04],
        do: refute(has_element?(view, "[data-role=today-link]")),
        else: assert(has_element?(view, ~s([data-role=today-link][href="/missal"])))
    end

    test "Missale Meum out of reach is said, and Try again asks only after a failure",
         %{conn: conn} do
      stub_down()
      {:ok, view, _html} = live(conn, "/missal/2026-11-04")
      render_async(view, 2000)
      assert has_element?(view, "[data-role=mass-failed]", "could not be reached")
      # The day's arrows still lead on.
      assert has_element?(view, ~s([data-role=next-day][href="/missal/2026-11-05"]))

      stub_missal()
      LumenViae.Office.Cache.isolate()
      view |> element("[data-role=retry]") |> render_click()
      render_async(view, 2000)
      assert has_element?(view, "[data-role=feast]", "St. Charles Borromeo")

      # A Try again sent while the Mass is shown does nothing.
      render_hook(view, "retry", %{})
      refute has_element?(view, "[data-role=mass-loading]")
      assert has_element?(view, "[data-role=feast]")
    end

    test "a day Missale Meum has no texts for says so", %{conn: conn} do
      stub_missal(%{"2026-11-06" => "[]"})
      {:ok, view, _html} = live(conn, "/missal/2026-11-06")
      render_async(view, 2000)
      assert has_element?(view, "[data-role=mass-none]")
    end

    test "Missale Meum's text is escaped, never markup", %{conn: conn} do
      day =
        Jason.encode!([
          %{
            "info" => %{"title" => "<b>Bold</b>", "rank" => 4, "colors" => ["g"]},
            "sections" => [
              %{"id" => "Oratio", "body" => [["<script>x()</script>", "<i>la</i>"]]}
            ]
          }
        ])

      stub_missal(%{"2026-11-07" => day})
      {:ok, view, _html} = live(conn, "/missal/2026-11-07")
      html = render_async(view, 2000)
      refute html =~ "<script>x()"
      refute html =~ "<b>Bold</b>"
      assert html =~ "&lt;b&gt;Bold&lt;/b&gt;"
    end

    test "a date that is not one, or outside the Missal's years, is a 404", %{conn: conn} do
      for path <- ["/missal/not-a-date", "/missal/2026-02-30", "/missal/1599-12-31"] do
        assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, path) end
      end
    end
  end

  describe "/missal/order-of-mass" do
    test "every Mass's fixed parts, rubrics apart, with the credit", %{conn: conn} do
      stub_missal()
      {:ok, view, html} = live(conn, "/missal/order-of-mass")

      assert html =~ "The Order of Mass"
      render_async(view, 2000)
      assert has_element?(view, "[data-role=rail] a", "Sprinkling with Holy Water")
      assert has_element?(view, "[data-role=rail] a", "Lord, Have Mercy")
      assert has_element?(view, "[data-role=rail] a", "Prayers after Mass")
      assert has_element?(view, "[data-role=rubric]", "On Sundays")
      refute has_element?(view, "[data-role=posture]")
      assert has_element?(view, "[data-role=credit]", "Missale Meum")
    end

    test "?lang=both pairs the Latin with the English", %{conn: conn} do
      stub_missal()
      {:ok, view, _html} = live(conn, "/missal/order-of-mass?lang=both")
      render_async(view, 2000)
      assert has_element?(view, "[data-role=paired]")
      view |> element("[data-role=language] a", "Latin") |> render_click()
      assert_patch(view, "/missal/order-of-mass?lang=latin")
    end

    test "out of reach is said, with Try again", %{conn: conn} do
      stub_down()
      {:ok, view, _html} = live(conn, "/missal/order-of-mass")
      render_async(view, 2000)
      assert has_element?(view, "[data-role=ordo-failed]")
      assert has_element?(view, "[data-role=retry]")
    end
  end

  describe "/missal/calendar/:year/:month" do
    test "the month by the days' vestments, each day its Mass", %{conn: conn} do
      stub_missal()
      {:ok, view, html} = live(conn, "/missal/calendar/2026/11")

      assert html =~ "November 2026"
      render_async(view, 2000)

      for day <- 1..30 do
        date = Date.new!(2026, 11, day)
        assert has_element?(view, ~s([data-role=day-cell][href="/missal/#{date}"]))
      end

      assert has_element?(
               view,
               ~s([data-date="2026-11-04"][aria-label="Wednesday, 4 November 2026. St. Charles Borromeo. White vestments"])
             )

      assert has_element?(view, ~s([data-date="2026-11-04"] .missal-silk--w))
      assert has_element?(view, ~s([data-date="2026-11-02"] .missal-silk--b))
      assert has_element?(view, ~s([data-role=next-month][href="/missal/calendar/2026/12"]))
    end

    test "today is marked by the visitor's date", %{conn: conn} do
      stub_missal()
      today = Date.utc_today()
      {:ok, view, _html} = live(conn, Days.calendar_path(today))
      refute has_element?(view, "[data-role=day-cell][aria-current]")
      render_hook(view, "set_timezone", %{"offset" => 0})
      assert has_element?(view, ~s([data-role=day-cell][aria-current][data-date="#{today}"]))
    end

    test "out of reach, every day still opens", %{conn: conn} do
      stub_down()
      {:ok, view, _html} = live(conn, "/missal/calendar/2026/11")
      render_async(view, 2000)
      assert has_element?(view, "[data-role=calendar-failed]")
      assert has_element?(view, ~s([data-role=day-cell][href="/missal/2026-11-04"]))
    end

    test "a month that is not one is a 404", %{conn: conn} do
      for path <- ["/missal/calendar/2026/13", "/missal/calendar/1599/1", "/missal/calendar/x/1"] do
        assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, path) end
      end
    end
  end

  describe "Hours of Prayer's landing" do
    test "names the day in English with its vestment colour, from the Missal", %{conn: conn} do
      stub_missal()

      Req.Test.stub(LumenViae.Office.DivinumOfficium, fn conn ->
        html =
          File.read!(
            Path.expand(
              "../../../support/fixtures/divinum_officium/kalendar_2026-08.html",
              __DIR__
            )
          )

        Req.Test.html(conn, html)
      end)

      {:ok, view, _html} = live(conn, "/hours/2026-08-27")
      render_async(view, 2000)
      assert has_element?(view, "[data-role=feast-english]", "St. Charles Borromeo")
      assert has_element?(view, "[data-role=day-class]", "White vestments")
      assert has_element?(view, "[data-role=day-class] .missal-silk--w")
    end
  end

  describe "Hours of Prayer's landing, the Office out of reach" do
    test "still names the day from the Missal, as iOS does", %{conn: conn} do
      stub_missal()
      Req.Test.stub(LumenViae.Office.DivinumOfficium, &Req.Test.transport_error(&1, :timeout))

      {:ok, view, _html} = live(conn, "/hours/2026-08-27")
      render_async(view, 2000)
      assert has_element?(view, "[data-role=feast-english]", "St. Charles Borromeo")
      assert has_element?(view, "[data-role=day-class]", "Lesser Feast · White vestments")
      refute has_element?(view, "[data-role=feast-failed]")
    end
  end

  describe "the sitemap and robots.txt" do
    test "list /missal and the Order of Mass, and keep crawlers out of the dated pages" do
      sitemap = File.read!(Application.app_dir(:lumen_viae, "priv/static/sitemap.xml"))
      robots = File.read!(Application.app_dir(:lumen_viae, "priv/static/robots.txt"))

      assert sitemap =~ "<loc>https://www.lumenviae.org/missal</loc>"
      assert sitemap =~ "<loc>https://www.lumenviae.org/missal/order-of-mass</loc>"
      refute sitemap =~ ~r{/missal/\d}
      refute sitemap =~ "/missal/calendar"
      assert robots =~ "Allow: /missal/order-of-mass\n"
      assert robots =~ "Disallow: /missal/\n"
    end
  end

  describe "the text" do
    test "a part named plainly, with its Latin name, posture and diamond" do
      [introit, preface] =
        MissalText.day_sections(
          [
            %{
              id: "Introitus",
              label: "Introit",
              body: [["*Ps 1:1*\nBlessed", "*Ps 1:1*\nBeatus"]]
            },
            %{id: "Prefatio", label: "Preface", body: [["It is truly meet", "Vere dignum"]]}
          ],
          "both"
        )

      assert introit.name == "Entrance Chant"
      assert introit.latin == "Introitus"
      assert introit.posture == "Stand"
      assert introit.proper?
      refute preface.proper?

      assert [{:paired, [{:citation, "Ps 1:1"}, {:versal_pair, _la, _en}]}] = introit.passages
    end

    test "a second lesson by its head, and an unknown part as the day's own" do
      [lesson, rite] =
        MissalText.day_sections(
          [
            %{id: "Lectio 2", label: "Lesson", body: [["a", "b"]]},
            %{id: "Benedictio Candelarum", label: "Blessing of Candles", body: [["a", "b"]]}
          ],
          "english"
        )

      assert lesson.name == "First Reading"
      assert lesson.posture == "Sit"
      assert rite.name == "Blessing of Candles"
      assert rite.proper?
      assert rite.posture == nil
    end

    test "a rubric and the placeholders read once, as notes" do
      assert MissalText.passage(["The priest bows."], "both") == {:note, "The priest bows."}

      assert MissalText.passage(
               ["– Introit in today Mass –", "– Introit in today Mass –"],
               "latin"
             ) ==
               {:note, "– Introit in today Mass –"}
    end

    test "sides that do not pair line for line stand as two blocks" do
      assert {:blocks, [_, _], [_]} = MissalText.passage(["one", "uno\nduo"], "both")
    end

    test "lines are cleaned as the app cleans them" do
      assert {:single, :latin, [{:line, runs}]} =
               MissalText.passage(["x", "S. Dóminus vobíscum."], "latin")

      assert Enum.map_join(runs, &elem(&1, 1)) == "P. Dóminus vobíscum."
    end

    test "the date pill and the paths" do
      assert Days.pill_date(~D[2026-11-02]) == "MON · 2 NOV"
      assert Days.day_path(~D[2026-11-02]) == "/missal/2026-11-02"
      assert Days.day_path(~D[2026-11-02], "both", 2) == "/missal/2026-11-02?mass=2&lang=both"
      assert Days.today_path("latin") == "/missal?lang=latin"
      assert Days.ordo_path() == "/missal/order-of-mass"
    end
  end
end
