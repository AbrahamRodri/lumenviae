defmodule LumenViaeWeb.Live.Missal.OrdinaryTest do
  @moduledoc """
  The Daily Missal read with the Ordinary, as the iOS app's
  `MissalOrderData` reads it: where each part of the Order of Mass stands
  among the day's own texts, the parts the day and a sung Mass decide,
  and the page's Contents and Spoken or Sung choices.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Office.MissaleMeum
  alias LumenViaeWeb.Live.Missal.{MissalText, Ordinary}

  @moduletag :capture_log

  @fixtures Path.expand("../../../support/fixtures/missale_meum", __DIR__)

  setup do
    LumenViae.Office.Cache.isolate()
    :ok
  end

  defp fixture(name), do: File.read!(Path.join(@fixtures, name))

  defp stub_missal(opts \\ []) do
    Req.Test.stub(MissaleMeum, fn conn ->
      case conn.request_path do
        "/en/api/v5/ordo" ->
          if opts[:ordo_down],
            do: Req.Test.transport_error(conn, :econnrefused),
            else: json(conn, fixture("ordo.json"))

        "/en/api/v5/proper/2026-11-02" ->
          json(conn, fixture("proper_2026-11-02.json"))

        "/en/api/v5/proper/" <> _date ->
          json(conn, fixture("proper_2026-11-04.json"))

        "/en/api/v5/calendar/" <> _year ->
          json(conn, fixture("calendar_2026.json"))
      end
    end)
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, body)
  end

  # The Order of Mass as the Office reads it, every part a rubric and a
  # prayer; the Preface its dialogue, the Common Preface and the Sanctus.
  defp ordo do
    labels = [
      "Asperges",
      "Prayers at the Foot of the Altar",
      "Kyrie",
      "Gloria",
      "Credo",
      "Offertory Prayers",
      "Incensing",
      "Lavabo",
      "Prayer to the Most Holy Trinity",
      "Orate Fratres",
      "Canon",
      "Pater Noster",
      "Fraction – Breaking of the Sacred Host",
      "Agnus Dei",
      "Prayers for Holy Communion",
      "Communion of the Priest",
      "Communion of the People",
      "Ablutions",
      "Conclusion",
      "The Last Gospel",
      "Prayers ordered by the pope Leo XIII"
    ]

    Enum.map(labels, &%{id: nil, label: &1, body: [["A rubric."], [&1 <> " en", &1 <> " la"]]}) ++
      [
        %{
          id: nil,
          label: "Offertory",
          body: [["℣. The Lord be with you.", "℣. Dóminus vobíscum."]]
        },
        %{id: nil, label: "Communion", body: [["Let us pray.", "Orémus."]]},
        %{
          id: nil,
          label: "Preface",
          body: [
            ["The priest begins."],
            ["Lift up your hearts", "Sursum corda"],
            ["It is truly meet", "Vere dignum"],
            ["Holy, holy, holy", "Sanctus, sanctus, sanctus"]
          ]
        },
        %{
          id: nil,
          label: "Introit",
          body: [["– Introit in today Mass –", "– Introit in today Mass –"]]
        }
      ]
  end

  defp propers(ids),
    do: Enum.map(ids, &%{id: &1, label: nil, body: [[&1 <> " en", &1 <> " la"]]})

  @day ~w(Introitus Oratio Lectio Graduale Evangelium Offertorium Secreta Prefatio Communio Postcommunio)

  defp names(propers, mass, opts),
    do:
      propers
      |> Ordinary.weave(ordo(), mass, opts)
      |> MissalText.mass_sections("english")
      |> Enum.map(& &1.name)

  # 4 November 2026 is a Wednesday, 8 November a Sunday.
  @weekday ~D[2026-11-04]
  @sunday ~D[2026-11-08]
  @white %{colors: ["w"], rank: 3}

  describe "where the Ordinary stands" do
    test "a weekday's spoken Mass, from the foot of the altar to the prayers after Mass" do
      assert names(propers(@day), @white, date: @weekday) == [
               "At the Foot of the Altar",
               "Entrance Chant",
               "Lord, Have Mercy",
               "Glory to God",
               "Opening Prayer",
               "First Reading",
               "Chant Between the Readings",
               "Gospel",
               "Offertory Chant",
               "Offertory Prayers",
               "Washing of the Hands",
               "Prayer to the Holy Trinity",
               "Pray, Brethren",
               "Prayer over the Gifts",
               "Lift Up Your Hearts",
               "Preface",
               "Holy, Holy, Holy",
               "Eucharistic Prayer",
               "Our Father",
               "Breaking of the Host",
               "Lamb of God",
               "Prayers for Holy Communion",
               "Communion of the Priest",
               "Communion of the People",
               "Cleansing of the Vessels",
               "Communion Chant",
               "Prayer after Communion",
               "The Mass Is Ended",
               "Closing Gospel",
               "Prayers after Mass"
             ]
    end

    test "a Sunday's sung Mass: the Asperges, the Creed and the incense, no prayers after" do
      names = names(propers(@day), @white, date: @sunday, sung?: true)

      assert hd(names) == "Sprinkling with Holy Water"
      assert Enum.drop_while(names, &(&1 != "Gospel")) |> Enum.take(2) == ["Gospel", "The Creed"]
      assert "Incensing" in names
      refute "Prayers after Mass" in names
    end

    test "a Sunday's spoken Mass has its Creed but not the Asperges" do
      names = names(propers(@day), @white, date: @sunday)
      assert "The Creed" in names
      refute "Sprinkling with Holy Water" in names
      refute "Incensing" in names
    end

    test "violet, black and rose put the Gloria away; a greater feast says the Creed" do
      for colour <- ~w(v b p),
          do: refute("Glory to God" in names(propers(@day), %{colors: [colour]}, date: @weekday))

      assert "The Creed" in names(propers(@day), %{colors: ["w"], rank: 2}, date: @weekday)
      assert "Glory to God" in names(propers(@day), %{colors: []}, date: @weekday)
    end

    test "the Ordinary's prayers only: its rubrics and placeholders stay on the Order of Mass" do
      sections = propers(@day) |> Ordinary.weave(ordo(), @white, date: @weekday)

      kyrie =
        Enum.find_value(sections, fn
          {:ordinary, %{name: "Lord, Have Mercy"} = p} -> p
          _ -> nil
        end)

      assert kyrie.body == [["Kyrie en", "Kyrie la"]]
      assert kyrie.latin == "Kyrie"
      assert kyrie.posture == :stand
    end

    test "the Offertory's dialogue opens the day's verse, or stands alone" do
      [_ | _] = sections = Ordinary.weave(propers(@day), ordo(), @white, date: @weekday)
      {:proper, 5, offertory} = Enum.find(sections, &match?({:proper, 5, _}, &1))
      assert hd(offertory.body) == ["℣. The Lord be with you.", "℣. Dóminus vobíscum."]

      names = names(propers(@day -- ["Offertorium"]), @white, date: @weekday)
      assert Enum.count(names, &(&1 == "Offertory Chant")) == 1

      assert Enum.find_index(names, &(&1 == "Offertory Chant")) <
               Enum.find_index(names, &(&1 == "Offertory Prayers"))
    end

    test "a day with no Preface of its own reads the Common Preface" do
      names = names(propers(@day -- ["Prefatio"]), @white, date: @weekday)

      assert Enum.drop_while(names, &(&1 != "Lift Up Your Hearts")) |> Enum.take(3) ==
               ["Lift Up Your Hearts", "Common Preface", "Holy, Holy, Holy"]
    end

    test "a part the tables do not know keeps the place Missale Meum gave it" do
      names = names(propers(["Introitus", "Benedictio", "Oratio"]), @white, date: @weekday)

      assert Enum.take(names, 5) ==
               [
                 "At the Foot of the Altar",
                 "Entrance Chant",
                 "Benedictio",
                 "Lord, Have Mercy",
                 "Glory to God"
               ]
    end

    test "with no Order of Mass the day's texts stand alone" do
      assert names(propers(@day), @white, date: @weekday) |> length() == 30

      only =
        propers(@day)
        |> Ordinary.weave(nil, @white, date: @weekday)
        |> MissalText.mass_sections("english")

      assert length(only) == 10
      assert hd(only).name == "Entrance Chant"
    end

    test "the versal opens the Introit, not the prayers before it" do
      [foot, introit | _] =
        propers(@day)
        |> Ordinary.weave(ordo(), @white, date: @weekday)
        |> MissalText.mass_sections("english")

      refute foot.proper?
      assert foot.posture == "Kneel"
      assert [{:single, :english, [{:versal, _runs}]}] = introit.passages
    end
  end

  describe "the day's page" do
    test "reads the Whole Mass by default, the Ordinary among the day's texts", %{conn: conn} do
      stub_missal()
      {:ok, view, _html} = live(conn, "/missal/2026-11-04")
      render_async(view, 2000)

      assert has_element?(view, "[data-role=contents] [aria-pressed=true]", "Whole Mass")
      assert has_element?(view, "[data-role=sung] [aria-pressed=true]", "Spoken")
      assert has_element?(view, "[data-role=rail] a", "At the Foot of the Altar")
      assert has_element?(view, "[data-role=rail] a", "Lord, Have Mercy")
      assert has_element?(view, "[data-role=rail] a", "Eucharistic Prayer")
      assert has_element?(view, "[data-role=rail] a", "Prayers after Mass")
      assert has_element?(view, "[data-role=rail] a", "Entrance Chant")
      refute has_element?(view, "[data-role=rail] a", "Incensing")
      # Wednesday, white: the Gloria, no Creed.
      assert has_element?(view, "[data-role=rail] a", "Glory to God")
      refute has_element?(view, "[data-role=rail] a", "The Creed")
      # The versal opens the Introit.
      assert has_element?(view, "#missal-0-introitus .missal-line--versal")
    end

    test "Today's texts only, and back; the choice goes to this browser", %{conn: conn} do
      stub_missal()
      {:ok, view, _html} = live(conn, "/missal/2026-11-04")
      render_async(view, 2000)

      view |> element("[data-role=contents] button", "Today's texts only") |> render_click()
      assert_push_event(view, "store_missal_reading", %{contents: "propers", sung: false})
      refute has_element?(view, "[data-role=rail] a", "Lord, Have Mercy")
      assert has_element?(view, "[data-role=rail] a", "Entrance Chant")
      refute has_element?(view, "[data-role=sung]")

      view |> element("[data-role=contents] button", "Whole Mass") |> render_click()
      assert_push_event(view, "store_missal_reading", %{contents: "whole", sung: false})
      assert has_element?(view, "[data-role=rail] a", "Lord, Have Mercy")
    end

    test "a sung Mass adds the incense and leaves out the prayers after Mass", %{conn: conn} do
      stub_missal()
      {:ok, view, _html} = live(conn, "/missal/2026-11-04")
      render_async(view, 2000)

      view |> element("[data-role=sung] button", "Sung") |> render_click()
      assert_push_event(view, "store_missal_reading", %{contents: "whole", sung: true})
      assert has_element?(view, "[data-role=rail] a", "Incensing")
      refute has_element?(view, "[data-role=rail] a", "Prayers after Mass")
    end

    test "what this browser chose before is read back", %{conn: conn} do
      stub_missal()
      {:ok, view, _html} = live(conn, "/missal/2026-11-04")
      render_async(view, 2000)

      render_hook(view, "restore_reading", %{"contents" => "propers", "sung" => true})
      assert has_element?(view, "[data-role=contents] [aria-pressed=true]", "Today's texts only")
      refute has_element?(view, "[data-role=rail] a", "Lord, Have Mercy")

      # Nonsense changes nothing.
      render_hook(view, "restore_reading", %{"contents" => "x", "sung" => "y"})
      assert has_element?(view, "[data-role=contents] [aria-pressed=true]", "Today's texts only")
      render_hook(view, "set_contents", %{"contents" => "x"})
      assert has_element?(view, "[data-role=contents] [aria-pressed=true]", "Today's texts only")
    end

    test "with the Order of Mass out of reach the day's texts stand alone", %{conn: conn} do
      stub_missal(ordo_down: true)
      {:ok, view, _html} = live(conn, "/missal/2026-11-04")
      render_async(view, 2000)

      assert has_element?(view, "[data-role=feast]", "St. Charles Borromeo")
      assert has_element?(view, "[data-role=rail] a", "Entrance Chant")
      refute has_element?(view, "[data-role=rail] a", "Lord, Have Mercy")
      refute has_element?(view, "[data-role=mass-failed]")
      refute has_element?(view, "[data-role=mass-loading]")
    end
  end
end
