defmodule LumenViaeWeb.Live.Prayers.OrderPagesTest do
  @moduledoc """
  The orders of prayer on the website: an order's page at
  `/prayers/orders/:order_id`, praying it at
  `/prayers/orders/:order_id/pray?step=&lang=`, the shortcuts and Now on
  `/prayers`, a topic's Pray together card and orders found by the search.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Prayers.{Book, Orders}

  describe "/prayers/orders/:order_id" do
    test "heads the order with when it is said and its name, then its prayers numbered", %{
      conn: conn
    } do
      {:ok, view, html} = live(conn, "/prayers/orders/before_confession")

      assert view |> element("h1") |> render() =~ "Before Confession"
      assert view |> element("[data-role=occasion]") |> render() =~ "Before going in"

      rows = html |> Floki.parse_document!() |> Floki.find("[data-role=order-prayer]")
      assert length(rows) == 6

      assert rows |> Enum.at(2) |> Floki.attribute("href") ==
               ["/prayers/orders/before_confession/pray?step=3"]

      assert rows |> hd() |> Floki.attribute("href") == ["/prayers/orders/before_confession/pray"]
      assert html =~ "Prayer before Confession"
    end

    test "Pray is the page's one gold act", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prayers/orders/morning")
      doc = Floki.parse_document!(html)

      assert [pray] = Floki.find(doc, "#order-page .btn-gold")
      assert Floki.attribute(pray, "href") == ["/prayers/orders/morning/pray"]
      assert Floki.attribute(pray, "data-role") == ["order-pray"]
    end

    test "Night Prayers close on a song to Mary", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prayers/orders/night")

      assert length(Floki.find(Floki.parse_document!(html), "[data-role=order-prayer]")) == 6
    end

    test "the visitor's offset is taken, and nonsense is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/orders/angelus")

      assert render_hook(view, "set_timezone", %{"offset" => 300}) =~ "order-prayer"
      assert render_hook(view, "set_timezone", %{"offset" => "x"}) =~ "order-prayer"
      assert render_hook(view, "set_timezone", %{}) =~ "order-prayer"
    end

    test "an unknown order is a 404", %{conn: conn} do
      error =
        assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/prayers/orders/nope") end

      assert Plug.Exception.status(error) == 404
    end
  end

  describe "/prayers/orders/:order_id/pray" do
    test "opens on the first prayer, its place among the order's, and the next named", %{
      conn: conn
    } do
      {:ok, view, html} = live(conn, "/prayers/orders/morning/pray")

      assert view |> element("h1") |> render() =~ "The Sign of the Cross"
      assert view |> element("[data-role=step-count]") |> render() =~ "1 of 9"
      assert view |> element("[data-role=order-title]") |> render() =~ "Morning Prayers"
      assert view |> element("[data-role=next]") |> render() =~ "The Morning Offering"
      refute has_element?(view, "[data-role=previous]")
      refute has_element?(view, "[data-role=amen]")
      assert html =~ ~s(data-layout="focused")
    end

    test "Next and the way back turn the page in the link", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/orders/morning/pray")

      view |> element("[data-role=next]") |> render_click()
      assert_patched(view, "/prayers/orders/morning/pray?step=2")
      assert view |> element("h1") |> render() =~ "The Morning Offering"

      view |> element("[data-role=previous]") |> render_click()
      assert_patched(view, "/prayers/orders/morning/pray")
    end

    test "the last prayer closes on Amen, and Amen on Done and Pray again", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/orders/table/pray?step=2&lang=latin")

      refute has_element?(view, "[data-role=next]")
      view |> element("[data-role=amen]") |> render_click()
      assert_patched(view, "/prayers/orders/table/pray?step=amen&lang=latin")

      assert view |> element("[data-role=closing]") |> render() =~ "At Meals · Prayed"
      assert view |> element("h1") |> render() =~ "Amen."

      assert view |> element("[data-role=done]") |> render() =~
               ~s(href="/prayers/orders/table")

      assert view |> element("[data-role=pray-again]") |> render() =~
               ~s(href="/prayers/orders/table/pray?lang=latin")
    end

    test "the language rides along from step to step", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers/orders/morning/pray?step=3&lang=both")

      assert html =~ "book-text--both"
      assert html =~ "Pater noster"

      assert view |> element("[data-role=next]") |> render() =~
               ~s(href="/prayers/orders/morning/pray?step=4&amp;lang=both")

      assert view |> element("[data-role=previous]") |> render() =~
               ~s(href="/prayers/orders/morning/pray?step=2&amp;lang=both")
    end

    test "a prayer with no Latin is set in English and keeps the choice", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers/orders/morning/pray?step=2&lang=latin")

      refute has_element?(view, "[data-role=language]")
      [text] = html |> Floki.parse_document!() |> Floki.find("[data-role=prayer-text]")
      assert Floki.attribute(text, "lang") == []
      assert view |> element("[data-role=next]") |> render() =~ "lang=latin"
    end

    test "the chooser patches the language into the link", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/orders/morning/pray?step=3")

      view |> element("[data-role=language] a", "Latin") |> render_click()
      assert_patched(view, "/prayers/orders/morning/pray?step=3&lang=latin")
      assert render(view) =~ "Pater noster"
    end

    test "a step past either end is the nearest prayer", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/orders/morning/pray?step=99")
      assert view |> element("[data-role=step-count]") |> render() =~ "9 of 9"
      assert has_element?(view, "[data-role=amen]")

      for step <- ["0", "-4"] do
        {:ok, view, _html} = live(conn, "/prayers/orders/morning/pray?step=#{step}")
        assert view |> element("[data-role=step-count]") |> render() =~ "1 of 9"
      end
    end

    test "no parameter breaks the page", %{conn: conn} do
      for query <- [
            "step=x",
            "step=2.5",
            "step=",
            "step[]=2",
            "step[a]=1",
            "lang=klingon",
            "lang[]=both",
            "lang[x]=latin",
            "step=amen&lang[]=x",
            "step=%00"
          ] do
        {:ok, view, _html} = live(conn, "/prayers/orders/morning/pray?" <> query)
        assert render(view) =~ "pray-along", query
      end
    end

    test "an order of one prayer is headed Prayers and has no beads", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/orders/angelus/pray")

      assert view |> element("[data-role=order-title]") |> render() =~ "Prayers"
      refute has_element?(view, "[data-role=step-count]")
      assert has_element?(view, "[data-role=amen]")
    end

    test "nothing on the page is an event: no completion, nothing sent", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/orders/table/pray?step=2")
      refute view |> element(".pray-along__layout") |> render() =~ "phx-click"
    end

    test "the visitor's offset is taken, and nonsense is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/orders/night/pray?step=6")

      assert render_hook(view, "set_timezone", %{"offset" => -600}) =~ "6 of 6"
      assert render_hook(view, "set_timezone", %{"offset" => [1]}) =~ "6 of 6"
    end

    test "an unknown order is a 404", %{conn: conn} do
      error =
        assert_raise LumenViaeWeb.NotFoundError, fn ->
          live(conn, "/prayers/orders/nope/pray?step=2")
        end

      assert Plug.Exception.status(error) == 404
    end

    test "Pray.step reads only whole numbers and amen" do
      alias LumenViaeWeb.Live.Prayers.Order.Pray

      assert Pray.step("amen", 9) == :amen
      assert Pray.step("3", 9) == 3
      assert Pray.step("12", 9) == 9
      assert Pray.step("0", 9) == 1
      assert Pray.step("3x", 9) == 1
      assert Pray.step(["3"], 9) == 1
      assert Pray.step(%{"a" => "3"}, 9) == 1
      assert Pray.step(nil, 9) == 1
    end
  end

  describe "/prayers" do
    test "opens on the shortcuts, the day's three orders and two for an occasion", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prayers")

      hrefs =
        html
        |> Floki.parse_document!()
        |> Floki.find("[data-role=shortcut]")
        |> Enum.flat_map(&Floki.attribute(&1, "href"))

      assert hrefs ==
               Enum.map(
                 ~w(morning angelus night before_mass before_confession),
                 &"/prayers/orders/#{&1}"
               )
    end

    test "Now is the order for the visitor's hour, with its own Pray", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers")

      # 14 hours west of UTC, then 14 east: the server's clock decides
      # which order each is, by Orders.day_order_id/1.
      for offset <- [-840, 0, 840] do
        html = render_hook(view, "set_timezone", %{"offset" => offset})
        {:ok, now} = Orders.local_now(offset)
        id = Orders.day_order_id(now.hour)

        [card] = html |> Floki.parse_document!() |> Floki.find("[data-role=now-card]")
        assert Floki.attribute(card, "data-order") == [id]

        assert card |> Floki.find("[data-role=now-pray]") |> Floki.attribute("href") ==
                 ["/prayers/orders/#{id}/pray"]

        assert Floki.text(card) =~ "Now ·"
      end
    end

    test "Now sits before Everyday Prayers, the shortcuts before both", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prayers")

      {shortcuts, _} = :binary.match(html, "data-role=\"shortcut\"")
      {now, _} = :binary.match(html, "data-role=\"now-card\"")
      {everyday, _} = :binary.match(html, "data-role=\"everyday-row\"")
      assert shortcuts < now and now < everyday
    end

    test "a search finds orders of prayer before the prayers", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers?q=blessed%20sacrament")

      assert has_element?(view, ~s([data-role=order-result][href="/prayers/orders/visit"]))
      {order, _} = :binary.match(html, "data-role=\"order-result\"")

      case :binary.match(html, "data-role=\"result-row\"") do
        {row, _} -> assert order < row
        :nomatch -> :ok
      end
    end

    test "an order found alone is not 'no prayer by that name'", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers?q=purgatory")

      assert has_element?(view, ~s([data-role=order-result][href="/prayers/orders/holy_souls"]))
      refute has_element?(view, "[data-role=no-match]")
    end
  end

  describe "a topic's Pray together card" do
    test "stands first on a topic with orders, a row for each", %{conn: conn} do
      {:ok, view, html} = live(conn, "/prayers/topics/mass")

      assert view |> element("[data-role=pray-together] h2") |> render() =~ "Pray together"

      assert html
             |> Floki.parse_document!()
             |> Floki.find("[data-role=topic-order]")
             |> Enum.flat_map(&Floki.attribute(&1, "href")) ==
               ["/prayers/orders/before_mass", "/prayers/orders/after_mass"]
    end

    test "is not on a topic without", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/topics/first")
      refute has_element?(view, "[data-role=pray-together]")
    end
  end

  describe "the sitemap" do
    test "lists every order's page and none of its pray steps" do
      sitemap = File.read!(Application.app_dir(:lumen_viae, "priv/static/sitemap.xml"))
      book = Book.load(nil)

      for order <- book.orders do
        assert sitemap =~ "<loc>https://www.lumenviae.org/prayers/orders/#{order.id}</loc>"
      end

      refute sitemap =~ "/pray</loc>"
    end

    test "robots.txt keeps crawlers out of the pray steps" do
      robots = File.read!(Application.app_dir(:lumen_viae, "priv/static/robots.txt"))
      assert robots =~ "Disallow: /prayers/orders/*/pray"
    end
  end
end
