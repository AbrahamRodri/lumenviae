defmodule LumenViaeWeb.Live.Prayers.AdventTest do
  @moduledoc """
  The Prayer Book in Advent: the This season shelf on /prayers and the
  Today mark on the O Antiphons and the wreath collects. Not async: the
  pages are drawn for a fixed day through the `:any_page_date?` setting.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Prayers.Book

  setup do
    previous = Application.get_env(:lumen_viae, :any_page_date?)
    Application.put_env(:lumen_viae, :any_page_date?, true)

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:lumen_viae, :any_page_date?),
        else: Application.put_env(:lumen_viae, :any_page_date?, previous)
    end)

    %{book: Book.load(nil)}
  end

  describe "Book.advent_cards/2" do
    test "the wreath from the eve of Advent to Christmas Eve, the O Antiphons first from 17 to 23 December",
         %{book: book} do
      ids = &Enum.map(Book.advent_cards(book, &1), fn card -> card.prayer.id end)

      assert ids.(~D[2026-11-27]) == []
      assert ids.(~D[2026-11-28]) == ["advent_wreath_collects"]
      assert ids.(~D[2026-11-29]) == ["advent_wreath_collects"]
      assert ids.(~D[2026-12-16]) == ["advent_wreath_collects"]
      assert ids.(~D[2026-12-17]) == ["o_antiphons", "advent_wreath_collects"]
      assert ids.(~D[2026-12-23]) == ["o_antiphons", "advent_wreath_collects"]
      assert ids.(~D[2026-12-24]) == ["advent_wreath_collects"]
      assert ids.(~D[2026-12-26]) == []
      assert ids.(~D[2027-01-10]) == []
    end

    test "each card names today's part and opens at it", %{book: book} do
      [antiphons, wreath] = Book.advent_cards(book, ~D[2026-12-21])

      assert antiphons.note == "December 21"
      assert antiphons.path == "/prayers/o_antiphons?on=2026-12-21#today"
      assert wreath.note == "The Fourth Sunday of Advent"
    end
  end

  describe "Book.season_mark/2" do
    test "the wreath's week runs from its Sunday's eve" do
      mark = &Book.season_mark("advent_wreath_collects", &1)

      assert mark.(~D[2026-11-28]) == "The First Sunday of Advent."
      assert mark.(~D[2026-12-05]) == "The Second Sunday of Advent."
      assert mark.(~D[2026-12-06]) == "The Second Sunday of Advent."
      assert mark.(~D[2026-12-13]) == "The Third Sunday of Advent."
      assert mark.(~D[2026-12-24]) == "The Fourth Sunday of Advent."
      assert mark.(~D[2026-12-25]) == nil
    end

    test "the O Antiphons mark their own day only" do
      assert Book.season_mark("o_antiphons", ~D[2026-12-17]) == "December 17."
      assert Book.season_mark("o_antiphons", ~D[2026-12-24]) == nil
      assert Book.season_mark("memorare", ~D[2026-12-17]) == nil
    end
  end

  test "a date in a link is believed only within a day of the server's, unless the setting is on" do
    Application.put_env(:lumen_viae, :any_page_date?, false)
    today = ~D[2026-12-21]

    assert Book.page_date("2026-12-20", today) == ~D[2026-12-20]
    assert Book.page_date("2026-12-01", today) == today
    assert Book.page_date("nonsense", today) == today
    assert Book.page_date(nil, today) == today
  end

  describe "/prayers in Advent" do
    test "This season shows the Advent prayers, the O Antiphons first on 21 December", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/prayers?on=2026-12-21")

      shelf = view |> element("[data-role=this-season-shelf]") |> render()
      assert shelf =~ "The O Antiphons"
      assert shelf =~ "December 21"
      assert shelf =~ ~s(href="/prayers/o_antiphons?on=2026-12-21#today")

      [first | _] = Floki.find(Floki.parse_fragment!(shelf), "[data-role=advent-card]")
      assert Floki.attribute(first, "href") == ["/prayers/o_antiphons?on=2026-12-21#today"]
    end

    test "outside Advent there is no Advent shelf", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers?on=2026-12-26")
      refute has_element?(view, "[data-role=this-season-shelf]")
    end
  end

  describe "the Advent prayers' pages" do
    test "the O Antiphons mark today's antiphon, the whole text kept", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/o_antiphons?on=2026-12-21")

      assert view |> element("#today") |> render() =~ "December 21."
      assert view |> element("#today [data-role=today]") |> render() =~ "Today"
      assert render(view) =~ "December 17."
      assert render(view) =~ "December 23."
    end

    test "the wreath collects mark this week's Sunday", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/advent_wreath_collects?on=2026-12-08")

      assert view |> element("#today") |> render() =~ "The Second Sunday of Advent."
    end

    test "out of season nothing is marked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/o_antiphons?on=2026-12-26")
      refute has_element?(view, "#today")
    end
  end
end
