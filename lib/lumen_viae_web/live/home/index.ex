defmodule LumenViaeWeb.Live.Home.Index do
  @moduledoc """
  The home page: the daily Rosary hub.

  Today's mysteries on the traditional schedule, in the visitor's own
  timezone (the `UserTimezone` hook sends `set_timezone`), with the five
  mysteries and their fruits, the meditation sets for them straight into
  prayer, the set-less forms of the Rosary, and every category as a card.

  The mysteries' names, fruits and paintings come from the database; a
  category whose mysteries are not there yet falls back to the labels
  `LumenViae.Rosary.Categories` gives each position.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.LiturgicalCalendar
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork
  alias LumenViae.Rosary.Categories
  alias LumenViaeWeb.PageMeta

  @schedule :traditional
  @numerals ~w(I II III IV V VI VII)
  @week_days Enum.zip(1..7, ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday))

  # A browser's offset is at most fourteen hours either side of UTC; the
  # bound is a week so the tests can move "today" by whole days, and
  # anything past it is not an offset at all.
  @max_offset_minutes 7 * 24 * 60

  @description "Pray the Holy Rosary each day with meditations from the saints: today's mysteries, the Scriptural Rosary and guided audio, from the Joyful to the Seven Sorrows."

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_admin

    categories = build_categories(actor)

    meditation_sets = Rosary.list_visible_meditation_sets_with_meditations!(actor: actor)

    {:ok,
     socket
     |> PageMeta.put("/",
       title: "Meditations on the Holy Rosary",
       description: @description,
       json_ld: [PageMeta.website(@description)]
     )
     |> assign(:categories, categories)
     |> assign(:meditation_sets, meditation_sets)
     |> assign_today(Date.utc_today())}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset}, socket)
      when is_integer(offset) and abs(offset) <= @max_offset_minutes do
    # The browser's offset is positive west of UTC (-180 is UTC+3).
    local_date =
      DateTime.utc_now()
      |> DateTime.add(-offset * 60, :second)
      |> DateTime.to_date()

    {:noreply, assign_today(socket, local_date)}
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  def handle_event("providence", _params, socket) do
    case socket.assigns.todays_sets do
      [] ->
        {:noreply, socket}

      sets ->
        chosen = Enum.random(sets)
        {:noreply, push_navigate(socket, to: "/meditation-sets/#{chosen.id}/pray")}
    end
  end

  defp assign_today(socket, date) do
    today_slug = date |> LiturgicalCalendar.recommended_mysteries(@schedule) |> Atom.to_string()
    today = Enum.find(socket.assigns.categories, &(&1.slug == today_slug))

    todays_sets = Enum.filter(socket.assigns.meditation_sets, &(&1.category == today_slug))

    socket
    |> assign(:today, date)
    |> assign(:today_category, today)
    |> assign(:todays_sets, todays_sets)
    |> assign(:week, week(date))
  end

  defp week(date) do
    today_dow = Date.day_of_week(date)

    Enum.map(@week_days, fn {dow, day_name} ->
      slug =
        date
        |> Date.add(dow - today_dow)
        |> LiturgicalCalendar.recommended_mysteries(@schedule)
        |> Atom.to_string()

      %{
        label: String.slice(day_name, 0, 3),
        day_name: day_name,
        mysteries: Categories.devotion_title(slug),
        today?: dow == today_dow
      }
    end)
  end

  defp build_categories(actor) do
    mysteries = Rosary.list_mysteries!(actor: actor)
    seven_sorrows_card = Rosary.get_category_card!("seven_sorrows", actor: actor)

    Enum.map(LiturgicalCalendar.categories(), fn category ->
      slug = Atom.to_string(category)
      count = Categories.mystery_count(slug)

      in_category =
        mysteries
        |> Enum.filter(&(&1.category == slug and &1.order in 1..count))
        |> Map.new(&{&1.order, &1})

      card_record =
        if Categories.card_mystery_key(slug),
          do: Map.get(in_category, 1),
          else: seven_sorrows_card

      %{
        slug: slug,
        numeral: Enum.at(@numerals, Categories.position(slug)),
        name: Categories.name(slug),
        title: "The " <> Categories.devotion_title(slug),
        subtitle: Categories.subtitle(slug),
        days: LiturgicalCalendar.days_in_words(category, @schedule),
        path: "/mysteries/#{slug}",
        painting: painting(card_record, slug),
        mysteries: mysteries_in_order(slug, count, in_category)
      }
    end)
  end

  defp mysteries_in_order(slug, count, in_category) do
    Enum.map(1..count, fn order ->
      case Map.get(in_category, order) do
        nil ->
          %{
            numeral: Enum.at(@numerals, order - 1),
            name: Categories.mystery_label(slug, order),
            fruit: nil
          }

        mystery ->
          %{numeral: Enum.at(@numerals, order - 1), name: mystery.name, fruit: mystery.fruit}
      end
    end)
  end

  # The card keeps the app's framing (MysteryCategory.cardFocalPoint), not
  # the painting's own focal point, which frames it on the mystery's page.
  defp painting(record, slug) do
    if Artwork.publishable?(record) do
      {x, y} = Categories.card_focal_point(slug)

      %{
        record: record,
        alt: record.image_alt,
        position: Artwork.object_position(x, y)
      }
    end
  end

  @doc false
  def has_audio?(set), do: Enum.any?(set.meditations, & &1.audio_url)

  @doc false
  def scriptural_path(slug), do: "/mysteries/#{slug}/pray?form=scriptural"

  @doc false
  def aloud_path(slug), do: "/mysteries/#{slug}/pray?form=holy"
end
