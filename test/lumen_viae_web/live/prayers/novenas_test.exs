defmodule LumenViaeWeb.Live.Prayers.NovenasTest do
  @moduledoc """
  The website's Novenas: the shelf on /prayers, the Novenas topic and the
  novena pages' trail through it.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Prayers.Book

  setup do
    %{book: Book.load(nil, novenas: true)}
  end

  describe "Book.novena_shelf/2" do
    test "every novena, the ones under way first, then by their next feast, then any time",
         %{book: book} do
      shelf = Book.novena_shelf(book, ~D[2026-11-30])
      ids = Enum.map(shelf, & &1.prayer.id)

      assert length(shelf) == map_size(book.novenas)

      # 30 November: the Immaculate Conception (from 29 Nov) and St Andrew
      # (from 30 Nov) are under way
      assert Enum.take(ids, 2) == ["immaculate_conception_novena", "st_andrew_novena"]
      assert Enum.at(shelf, 0).note == "Now, to December 7"
      assert Enum.at(shelf, 1).note == "Now, to December 24"
      assert Enum.at(shelf, 2).prayer.id == "our_lady_of_guadalupe_novena"
      assert Enum.at(shelf, 2).note == "December 12"
      assert List.last(shelf).note == "Any time"
    end

    test "on the feast itself the novena is over, and its feast is today", %{book: book} do
      shelf = Book.novena_shelf(book, ~D[2026-12-08])
      by_id = Map.new(shelf, &{&1.prayer.id, &1})

      # Guadalupe (3 to 11 December) is under way and leads
      assert hd(shelf).prayer.id == "our_lady_of_guadalupe_novena"
      assert by_id["immaculate_conception_novena"].note == "December 8"
    end

    test "a feast kept from Easter moves with it" do
      assert Book.next_feast(%{kind: "easter", days_from_easter: 49}, ~D[2026-11-15]) ==
               ~D[2027-05-16]

      assert Book.next_feast(%{kind: "fixed", month: 3, day: 19}, ~D[2026-11-15]) ==
               ~D[2027-03-19]

      assert Book.next_feast(nil, ~D[2026-11-15]) == nil
    end
  end

  test "/prayers has a Novenas shelf linking each novena", %{conn: conn, book: book} do
    {:ok, view, _html} = live(conn, "/prayers")

    shelf = view |> element("[data-role=novenas-shelf]") |> render()

    assert length(Floki.find(Floki.parse_fragment!(shelf), "[data-role=novena-card]")) ==
             map_size(book.novenas)

    assert shelf =~ ~s(href="/prayers/st_joseph_novena")
    assert shelf =~ ~s(href="/prayers/topics/novenas")
  end

  test "the Novenas topic lists every novena by title", %{conn: conn, book: book} do
    {:ok, view, html} = live(conn, "/prayers/topics/novenas")

    assert html =~ "Novenas"

    for twin <- Map.keys(book.novenas) do
      assert has_element?(view, ~s(a[href="/prayers/#{twin}"]))
    end
  end

  test "a novena's page goes back to Novenas", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/prayers/st_joseph_novena")

    assert view |> element("[data-role=home-chapter]") |> render() =~ "Novenas"
    assert view |> element("[data-role=home-chapter]") |> render() =~ "/prayers/topics/novenas"
  end

  test "searching novena finds the topic", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/prayers?q=novena")
    assert html =~ "/prayers/topics/novenas"
  end
end
