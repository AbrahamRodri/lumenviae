defmodule LumenViaeWeb.Live.Prayers.NovenaTest do
  @moduledoc """
  A novena on its twin's page, one day at a time (`?day=`), and the rules
  that set a day (`LumenViaeWeb.Live.Prayers.Novena`). The book is the one
  in `priv/library/prayer_book.json`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Prayers.{Book, Novena}
  alias LumenViaeWeb.Live.Prayers.Prayer.Novena, as: NovenaDay

  describe "/prayers/:prayer_id for a novena's twin" do
    test "opens on day 1 with a chip a day, each a link", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/st_joseph_novena")

      assert view |> element("h1") |> render() =~ "St Joseph"
      assert view |> element("[data-role=day-count]") |> render() =~ "Day 1 of 9"
      assert view |> element("#novena-day-heading") |> render() =~ "The First Day"

      chips = view |> render() |> Floki.parse_document!() |> Floki.find("[data-role=day-chip]")
      assert length(chips) == 9

      assert chips |> Enum.map(&(Floki.attribute(&1, "href") |> hd())) ==
               ["/prayers/st_joseph_novena"] ++
                 for(n <- 2..9, do: "/prayers/st_joseph_novena?day=#{n}")

      assert has_element?(view, "[data-role=day-chip][aria-current=page]", "1")
      refute has_element?(view, "a[rel=prev]")

      assert has_element?(
               view,
               ~s(a[rel=next][href="/prayers/st_joseph_novena?day=2#novena-days"])
             )

      refute has_element?(view, "[data-role=language]")
    end

    test "?day=5 sets that day alone, with the prayers said every day", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers/st_joseph_novena?day=5")

      assert view |> element("#novena-day-heading") |> render() =~ "The Fifth Day"
      assert has_element?(view, "[data-role=day-chip][aria-current=page]", "5")
      refute html =~ "The First Day"
      assert html =~ "Novena Prayer"
      assert html =~ "The Memorare to St Joseph"
      assert view |> element("[data-role=rubric]") |> render() =~ "Here name your request."

      assert has_element?(
               view,
               ~s(a[rel=prev][href="/prayers/st_joseph_novena?day=4#novena-days"])
             )

      assert has_element?(
               view,
               ~s(a[rel=next][href="/prayers/st_joseph_novena?day=6#novena-days"])
             )
    end

    test "a chip patches the day into the link, day 1 left out", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/st_joseph_novena")

      view |> element("[data-role=day-chip]", "3") |> render_click()
      assert_patched(view, "/prayers/st_joseph_novena?day=3")
      assert view |> element("#novena-day-heading") |> render() =~ "The Third Day"

      view |> element("[data-role=day-chip]", "1") |> render_click()
      assert_patched(view, "/prayers/st_joseph_novena")
      assert view |> element("#novena-day-heading") |> render() =~ "The First Day"
    end

    test "a day the novena does not have is day 1", %{conn: conn} do
      for day <- ~w(0 10 -2 abc 2.5) do
        {:ok, view, _html} = live(conn, "/prayers/st_joseph_novena?day=#{day}")
        assert view |> element("#novena-day-heading") |> render() =~ "The First Day"
      end
    end

    # No novena in the book prays the Rosary inside its days now, so the
    # day is built here and set with the page's own component.
    test "the Rosary and the everyday prayers are direction lines" do
      book = Book.load(nil)

      part = fn fields ->
        Map.merge(
          %{
            kind: "prayer",
            prayer_id: nil,
            or_prayer_id: nil,
            times: nil,
            id: nil,
            title: nil,
            text: nil,
            source: nil,
            decades: nil
          },
          fields
        )
      end

      day = %{
        number: 1,
        title: "The First Day",
        parts: [
          part.(%{kind: "opening", prayer_id: "sign_of_cross"}),
          part.(%{kind: "prayer", prayer_id: "act_of_contrition"}),
          part.(%{kind: "rosary", decades: [1, 2, 3]}),
          part.(%{kind: "meditation", id: "fixture_d1", title: "Meditation", text: "Words."}),
          part.(%{kind: "rosary", decades: [4, 5]})
        ]
      }

      novena = %{days: [day, %{day | number: 2, title: "The Second Day"}], note: nil}

      doc =
        render_component(&NovenaDay.novena_day/1,
          novena: novena,
          prayer_id: "fixture_novena",
          day: 1,
          blocks: Novena.blocks(day, book)
        )
        |> Floki.parse_document!()

      directions =
        doc
        |> Floki.find("[data-role=novena-direction]")
        |> Enum.map(&(Floki.text(&1) |> String.trim()))

      assert directions == [
               "The Sign of the Cross.",
               "Pray the first three decades of the Rosary.",
               "Pray the last two decades of the Rosary."
             ]

      assert [_] =
               Floki.find(doc, ~s([data-role=novena-direction] a[href="/prayers/sign_of_cross"]))

      assert doc
             |> Floki.find(~s([data-role=novena-direction] a[href="/"]))
             |> Enum.map(&Floki.text/1) == ["the Rosary", "the Rosary"]

      assert Floki.raw_html(doc) =~ "The Act of Contrition"
    end

    test "a novena the same every day has no chips (St Andrew, 25 days)", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers/st_andrew_novena?day=7")

      refute has_element?(view, "[data-role=novena-days]")
      refute has_element?(view, "a[rel=next]")

      assert view |> element("[data-role=day-count]") |> render() =~
               "Each of the 25 days"

      assert html =~ "Said fifteen times."
      assert html =~ "Hail and blessed be the hour"
    end

    test "a prayer that may be said in a part's place is named", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/immaculate_conception_novena?day=9")

      assert view |> element("#novena-day-heading") |> render() =~ "Ninth"
      assert has_element?(view, ~s([data-role=novena-part] a[href="/prayers/litany_loreto"]))

      assert view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("[data-role=novena-direction]")
             |> Enum.map(&Floki.text/1)
             |> Enum.join() =~
               "The Hail Mary nine times and the Glory Be."
    end

    test "a prayer that is not a novena's twin keeps its whole text", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/memorare")

      refute has_element?(view, "[data-role=novena]")
      assert has_element?(view, "[data-role=prayer-text]")
    end
  end

  describe "the rules" do
    test "decades are named as the twin names them" do
      assert Novena.decades_phrase([1, 2, 3]) == "the first three decades"
      assert Novena.decades_phrase([4, 5]) == "the last two decades"
      assert Novena.decades_phrase([1, 2, 3, 4, 5]) == "the five decades"
      assert Novena.decades_phrase([3]) == "the third decade"
      assert Novena.decades_phrase([2, 4]) == "decades 2, 4"
    end

    test "times" do
      assert Novena.times_phrase(nil) == nil
      assert Novena.times_phrase(1) == nil
      assert Novena.times_phrase(2) == "twice"
      assert Novena.times_phrase(9) == "nine times"
      assert Novena.times_phrase(40) == "40 times"
    end
  end
end
