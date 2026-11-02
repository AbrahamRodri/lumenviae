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

    test "the Angelus hangs its still gold bell over the title, and no other order", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/prayers/orders/angelus/pray")
      assert has_element?(view, ".pray-along__words [data-role=bell]")

      {:ok, view, _html} = live(conn, "/prayers/orders/morning/pray")
      refute has_element?(view, "[data-role=bell]")
    end

    test "Pray again turns back with one counter-clockwise arrow", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers/orders/table/pray?step=amen")

      again = view |> element("[data-role=pray-again]") |> render()
      assert again =~ ~s(data-role="pray-again-icon")
      refute again =~ "hero-arrow-path"
    end

    test "Done and the close go back where the prayer was begun", %{conn: conn} do
      back = fn query ->
        {:ok, view, _html} = live(conn, "/prayers/orders/table/pray?" <> query)

        [href] =
          view
          |> render()
          |> Floki.parse_document!()
          |> Floki.attribute("[data-role=done]", "href")

        href
      end

      assert back.("step=amen&from=prayers") == "/prayers"
      assert back.("step=amen&from=topic%3Amass") == "/prayers/topics/mass"
      assert back.("step=amen") == "/prayers/orders/table"
      assert back.("step=amen&from=topic%3Anowhere") == "/prayers/orders/table"
      assert back.("step=amen&from=elsewhere") == "/prayers/orders/table"
      assert back.("step=amen&from[]=prayers") == "/prayers/orders/table"

      {:ok, view, _html} = live(conn, "/prayers/orders/table/pray?from=prayers")

      assert view |> element("[data-role=close]") |> render() =~ ~s(href="/prayers")
      assert view |> element("[data-role=close]") |> render() =~ "Close, back to Prayers"

      view |> element("[data-role=next]") |> render_click()
      assert_patched(view, "/prayers/orders/table/pray?step=2&from=prayers")
    end

    test "the head names the order as the day does", %{conn: conn} do
      angelus = Orders.order(Book.load(nil), "angelus")
      title = Orders.title(angelus, Date.utc_today())

      html = conn |> get("/prayers/orders/angelus/pray") |> html_response(200)
      assert html =~ ~s(<meta property="og:title" content="Pray #{title}">)

      html = conn |> get("/prayers/orders/angelus") |> html_response(200)
      assert html =~ ~s(<meta property="og:title" content="#{title}">)
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
      # The hour is read on either side of the render, so a run that
      # crosses a turn still agrees with one of them.
      for offset <- [-840, 0, 840] do
        {:ok, before} = Orders.local_now(offset)
        html = render_hook(view, "set_timezone", %{"offset" => offset})
        {:ok, later} = Orders.local_now(offset)

        [card] = html |> Floki.parse_document!() |> Floki.find("[data-role=now-card]")
        [id] = Floki.attribute(card, "data-order")
        assert id in [Orders.day_order_id(before.hour), Orders.day_order_id(later.hour)]

        assert card |> Floki.find("[data-role=now-pray]") |> Floki.attribute("href") ==
                 ["/prayers/orders/#{id}/pray?from=prayers"]

        assert Floki.text(card) =~ "Now ·"
      end
    end

    test "Now sits before Everyday Prayers, the shortcuts before both", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers")
      html = render_hook(view, "set_timezone", %{"offset" => 0})

      {shortcuts, _} = :binary.match(html, "data-role=\"shortcut\"")
      {now, _} = :binary.match(html, "data-role=\"now-card\"")
      {everyday, _} = :binary.match(html, "data-role=\"everyday-row\"")
      assert shortcuts < now and now < everyday
    end

    test "Now waits for the visitor's clock rather than show the hour in UTC", %{conn: conn} do
      html = conn |> get("/prayers") |> html_response(200)
      assert html =~ ~s(data-role="now-waiting")
      refute html =~ ~s(data-role="now-card")

      {:ok, view, _html} = live(conn, "/prayers")
      assert has_element?(view, "[data-role=now-waiting]")

      render_hook(view, "set_timezone", %{"offset" => -60})
      assert has_element?(view, "[data-role=now-card]")
      refute has_element?(view, "[data-role=now-waiting]")

      # Nonsense never stands for a clock.
      {:ok, view, _html} = live(conn, "/prayers")
      render_hook(view, "set_timezone", %{"offset" => "x"})
      assert has_element?(view, "[data-role=now-waiting]")
    end

    test "Now turns with the hour while the page is open", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prayers")

      # A turn before the clock is known changes nothing.
      send(view.pid, :turn)
      assert has_element?(view, "[data-role=now-waiting]")

      render_hook(view, "set_timezone", %{"offset" => 0})
      send(view.pid, :turn)
      assert has_element?(view, "[data-role=now-card]")
    end

    test "the book's hour turns at four, eleven, three and eight" do
      at = fn time -> Orders.next_turn_in(NaiveDateTime.new!(~D[2026-11-02], time)) end

      assert at.(~T[10:59:30]) == 30_000
      assert at.(~T[11:00:00]) == :timer.hours(4)
      assert at.(~T[15:30:00]) == :timer.minutes(270)
      assert at.(~T[20:00:00]) == :timer.hours(8)
      assert at.(~T[23:00:00]) == :timer.hours(5)
      assert at.(~T[03:59:59]) == 1_000
    end

    test "a book without the day's order draws no Now card" do
      alias LumenViaeWeb.Live.Prayers.Index.Shelves

      assert Orders.day_order(%Book{orders: []}, ~N[2026-11-02 09:00:00]) == nil

      assert render_component(&Shelves.now_card/1, order: nil, today: ~D[2026-11-02], hour: 9) ==
               ""
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
