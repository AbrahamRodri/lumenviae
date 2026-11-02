defmodule LumenViaeWeb.Live.Prayers.OrdersTest do
  @moduledoc """
  The orders of prayer's rules (`LumenViaeWeb.Live.Prayers.Orders`), the
  iOS app's: the hour's order, the Angelus in Eastertide, Night Prayers'
  closing song by season, the paintings and the search. Easter 2026 is
  5 April, Pentecost 24 May, Trinity Sunday 31 May; Advent begins on
  29 November.
  """
  use ExUnit.Case, async: true

  alias LumenViae.LiturgicalCalendar
  alias LumenViaeWeb.Components.MysteryPainting
  alias LumenViaeWeb.Live.Prayers.{Book, Orders}

  setup_all do
    %{book: Book.load(nil)}
  end

  describe "the hour's order (PrayerBook.dayOrder)" do
    test "morning from four until eleven, the Angelus until eight, night after" do
      for {hour, id} <- [
            {0, "night"},
            {3, "night"},
            {4, "morning"},
            {10, "morning"},
            {11, "angelus"},
            {15, "angelus"},
            {19, "angelus"},
            {20, "night"},
            {23, "night"}
          ] do
        assert Orders.day_order_id(hour) == id, "hour #{hour}"
      end
    end

    test "the Angelus is Noon's until three, then the Evening's until four" do
      assert Orders.hour_name("angelus", 11) == "Noon"
      assert Orders.hour_name("angelus", 14) == "Noon"
      assert Orders.hour_name("angelus", 15) == "Evening"
      assert Orders.hour_name("angelus", 2) == "Evening"
      assert Orders.hour_name("morning", 7) == "Morning"
      assert Orders.hour_name("night", 22) == "Night"
    end

    test "the visitor's clock comes from the browser's offset, anything else is no clock" do
      {:ok, now} = Orders.local_now(300)
      utc = NaiveDateTime.utc_now()
      assert_in_delta NaiveDateTime.diff(utc, now, :minute), 300, 1

      assert Orders.local_now("300") == :error
      assert Orders.local_now(99_999) == :error
      assert Orders.local_now(nil) == :error
    end
  end

  describe "the Angelus in Eastertide" do
    test "is Queen of Heaven, the Regina Caeli, from Easter to the eve of Trinity Sunday",
         %{book: book} do
      angelus = Orders.order(book, "angelus")

      for {date, title, ids} <- [
            {~D[2026-04-04], "The Angelus", ["angelus"]},
            {~D[2026-04-05], "Queen of Heaven", ["regina_caeli"]},
            {~D[2026-05-30], "Queen of Heaven", ["regina_caeli"]},
            {~D[2026-05-31], "The Angelus", ["angelus"]}
          ] do
        assert Orders.title(angelus, date) == title, Date.to_string(date)
        assert Orders.prayer_ids(book, angelus, date) == ids, Date.to_string(date)
      end
    end

    test "says why on its page, and only then", %{book: book} do
      angelus = Orders.order(book, "angelus")

      assert Orders.season_note(angelus, ~D[2026-04-20]) ==
               "Said in place of the Angelus until Pentecost."

      assert Orders.season_note(angelus, ~D[2026-11-02]) == nil
      assert Orders.season_note(Orders.order(book, "night"), ~D[2026-04-20]) == nil
    end

    test "hangs the risen Christ with His Mother in Eastertide, the Annunciation otherwise",
         %{book: book} do
      angelus = Orders.order(book, "angelus")

      assert Orders.hour_painting(angelus, ~D[2026-11-02]) == {"joyful_annunciation", 0.5, 0.18}
      {easter, _x, _y} = Orders.hour_painting(angelus, ~D[2026-04-20])
      assert easter == "glorious_resurrection"
    end

    test "the calendar keeps Eastertide from Easter Sunday to the Saturday before Trinity" do
      refute LiturgicalCalendar.eastertide?(~D[2026-04-04])
      assert LiturgicalCalendar.eastertide?(~D[2026-04-05])
      assert LiturgicalCalendar.eastertide?(~D[2026-05-30])
      refute LiturgicalCalendar.eastertide?(~D[2026-05-31])
    end
  end

  describe "Night Prayers close on the season's song to Mary" do
    test "each season its own", %{book: book} do
      night = Orders.order(book, "night")

      for {date, song} <- [
            {~D[2026-01-15], "alma_redemptoris"},
            {~D[2026-02-02], "ave_regina_caelorum"},
            {~D[2026-04-05], "regina_caeli"},
            {~D[2026-05-30], "hail_holy_queen"},
            {~D[2026-11-02], "hail_holy_queen"},
            {~D[2026-11-28], "alma_redemptoris"}
          ] do
        ids = Orders.prayer_ids(book, night, date)
        assert List.last(ids) == song, Date.to_string(date)
        assert Enum.take(ids, 5) == night.prayer_ids
      end
    end

    test "no other order closes on one", %{book: book} do
      morning = Orders.order(book, "morning")
      assert Orders.prayer_ids(book, morning, ~D[2026-11-02]) == morning.prayer_ids
    end
  end

  describe "which orders" do
    test "the shortcuts are the day's three, then Before Mass and Before Confession",
         %{book: book} do
      assert book |> Orders.shortcut_orders() |> Enum.map(& &1.id) ==
               ~w(morning angelus night before_mass before_confession)
    end

    test "a topic holds the orders the book puts under it", %{book: book} do
      assert book |> Orders.chapter_orders("day") |> Enum.map(& &1.id) ==
               ~w(morning angelus night table)

      assert book |> Orders.chapter_orders("mass") |> Enum.map(& &1.id) ==
               ~w(before_mass after_mass)

      assert Orders.chapter_orders(book, "first") == []
    end

    test "an order of one prayer bearing its name is headed Prayers", %{book: book} do
      angelus = Orders.order(book, "angelus")
      prayers = Orders.prayers(book, angelus, ~D[2026-11-02])

      assert Orders.kicker("The Angelus", prayers) == "Prayers"
      assert Orders.kicker("Morning Prayers", [hd(prayers), hd(prayers)]) == "Morning Prayers"
    end
  end

  describe "paintings" do
    test "every order hangs a painting the website has", %{book: book} do
      for order <- book.orders, date <- [~D[2026-04-20], ~D[2026-11-02]] do
        for painting <- [
              Orders.painting(order, date),
              Orders.page_painting(order, date),
              Orders.hour_painting(order, date)
            ] do
          {name, _x, _y} = painting
          assert MysteryPainting.for_name(name), "#{order.id}: #{name}"
        end
      end
    end

    test "Night Prayers' page hangs its painting from the top", %{book: book} do
      {_name, _x, y} = Orders.page_painting(Orders.order(book, "night"), ~D[2026-11-02])
      assert y == 0.0
    end
  end

  describe "search (PrayerBook.searchOrders)" do
    test "finds an order by its title, Latin, occasion or other names", %{book: book} do
      found = fn q -> book |> Orders.search(q, ~D[2026-11-02]) |> Enum.map(& &1.id) end

      assert "visit" in found.("blessed sacrament")
      assert "table" in found.("grace")
      assert "holy_souls" in found.("purgatory")
      assert "morning" in found.("morning")
      assert "before_confession" in found.("before confession")
      assert found.("zzqxv") == []
      assert found.("") == []
    end

    test "in Eastertide the Angelus answers to its name for the season", %{book: book} do
      assert "angelus" in Enum.map(
               Orders.search(book, "queen of heaven", ~D[2026-04-20]),
               & &1.id
             )

      refute "angelus" in Enum.map(
               Orders.search(book, "queen of heaven", ~D[2026-11-02]),
               & &1.id
             )
    end
  end

  describe "links" do
    test "never write a default" do
      assert Orders.pray_path("night") == "/prayers/orders/night/pray"
      assert Orders.pray_path("night", 1, "english") == "/prayers/orders/night/pray"
      assert Orders.pray_path("night", 3, "both") == "/prayers/orders/night/pray?step=3&lang=both"
      assert Orders.pray_path("night", :amen) == "/prayers/orders/night/pray?step=amen"
    end
  end
end
