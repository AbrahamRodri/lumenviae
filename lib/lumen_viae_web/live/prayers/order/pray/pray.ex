defmodule LumenViaeWeb.Live.Prayers.Order.Pray do
  @moduledoc """
  `/prayers/orders/:order_id/pray`: an order of prayer prayed in silence,
  as the app's `PrayAlongView` prays it. The order's painting hangs behind
  the words, veiled; the head is the way back, the order's name and its
  beads (a link to each prayer, "2 of 9"); the page is the prayer, its
  second name over its title and its words in the chosen language; and the
  foot is one way on, the next prayer named, or Amen on the last. Amen
  closes on the order's painting, "MORNING PRAYERS · PRAYED", Done (back
  to the order) and Pray again. A way back to the prayer before stands
  beside Next, where the app turns back with a swipe. On a wide screen a
  rail beside the words lists the order's prayers.

  The place rides in the link: `?step=2` counts the prayers from 1 (the
  first is never written; past either end is the nearest prayer; anything
  else is the first), `?step=amen` is the close, and the language comes
  with it as on a prayer's page (`?lang=latin` or `both`), carried from
  step to step. A prayer with no Latin is set in English and keeps the
  choice for the next.

  Nothing is sound, sent or kept: no voice, no completion, no record that
  the order was prayed. The day is the visitor's, as on the order's page.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Prayers.{Book, Orders, PrayerText}
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Prayers.Painting
  import LumenViaeWeb.Live.Prayers.Prayer.Text

  @language_labels [{"english", "English"}, {"latin", "Latin"}, {"both", "Both"}]

  @impl true
  def mount(%{"order_id" => id}, _session, socket) do
    book = Book.load(socket.assigns.current_admin)

    order =
      Orders.order(book, id) ||
        raise LumenViaeWeb.NotFoundError, message: "unknown order of prayer: #{id}"

    {:ok,
     socket
     |> PageMeta.put(Orders.pray_path(id),
       title: "Pray #{order.title}",
       description: "#{order.title}, prayed one prayer after another: #{order.detail}",
       trail: [
         {"Prayers", "/prayers"},
         {order.title, Orders.order_path(id)},
         {"Pray", Orders.pray_path(id)}
       ]
     )
     |> assign(:book, book)
     |> assign(:order, order)
     |> assign(:languages, @language_labels)
     |> assign(:date, Date.utc_today())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:step_param, params["step"])
     |> assign(:language, PrayerText.language(params["lang"]))
     |> assign_page()}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case Book.local_date(offset) do
      {:ok, date} -> {:noreply, socket |> assign(:date, date) |> assign_page()}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  defp assign_page(socket) do
    %{book: book, order: order, date: date, language: language} = socket.assigns
    title = Orders.title(order, date)
    prayers = Orders.prayers(book, order, date)

    socket
    |> assign(:title, title)
    |> assign(:kicker, Orders.kicker(title, prayers))
    |> assign(:prayers, prayers)
    |> assign(:count, length(prayers))
    |> assign(:painting, Orders.pray_painting(book, order, prayers, date))
    |> assign_step(step(socket.assigns.step_param, length(prayers)), prayers, language)
  end

  # An order whose prayers the book no longer prints has nothing to pray.
  defp assign_step(socket, _step, [], _language) do
    raise LumenViaeWeb.NotFoundError, message: "no prayers in #{socket.assigns.order.id}"
  end

  defp assign_step(socket, :amen, _prayers, _language) do
    socket
    |> assign(:step, :amen)
    |> assign(:prayer, nil)
    |> assign(:previous, nil)
    |> assign(:next, nil)
  end

  defp assign_step(socket, step, prayers, language) do
    prayer = Enum.at(prayers, step - 1)
    shown = if prayer.latin, do: language, else: "english"

    socket
    |> assign(:step, step)
    |> assign(:prayer, prayer)
    |> assign(:shown_language, shown)
    |> assign(:stanzas, PrayerText.stanzas(prayer.english, prayer.latin, shown))
    |> assign(:previous, if(step > 1, do: Enum.at(prayers, step - 2)))
    |> assign(:next, Enum.at(prayers, step))
  end

  @doc """
  The step a link names: `:amen` for the close, else a whole number held
  to the order's prayers, and the first for anything else (a list, a map,
  "2.5", "x").
  """
  def step("amen", count) when count > 0, do: :amen

  def step(param, count) when is_binary(param) do
    case Integer.parse(param) do
      {n, ""} -> n |> max(1) |> min(max(count, 1))
      _other -> 1
    end
  end

  def step(_param, _count), do: 1
end
