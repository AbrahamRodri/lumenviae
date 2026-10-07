defmodule LumenViaeWeb.Live.Mysteries.CategoryList do
  @moduledoc """
  `/mysteries/:category`: where a visitor chooses how to pray one
  category's mysteries. The category's painting, days and mysteries with
  their fruits; the two ways to pray it without a set; the shelf of its
  meditation sets, filtered by kind or narration, or one chosen by Divine
  Providence; and the "Your Rosary Today" choices every Pray link carries
  (`PrayLinks`), which the `RosaryChoices` hook keeps in the browser.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.LiturgicalCalendar
  alias LumenViae.Rosary
  alias LumenViae.Rosary.{Categories, Voices}
  alias LumenViaeWeb.PageMeta
  alias LumenViaeWeb.Live.Mysteries.CategoryList.{Filtering, PrayLinks}

  import LumenViaeWeb.Live.Mysteries.CategoryList.Header
  import LumenViaeWeb.Live.Mysteries.CategoryList.Choices
  import LumenViaeWeb.Live.Mysteries.CategoryList.WaysToPray
  import LumenViaeWeb.Live.Mysteries.CategoryList.Shelf

  @calendar_categories Map.new(LiturgicalCalendar.categories(), &{Atom.to_string(&1), &1})

  # The woodcut a category's header shows until its own painting is
  # published: the same prints the mysteries in Scripture page uses.
  @woodcuts %{
    "joyful" =>
      {"/images/woodcuts/annunciation-durer.jpg", "The Annunciation, woodcut by Albrecht Durer"},
    "sorrowful" =>
      {"/images/woodcuts/crucifixion-durer.jpg", "The Crucifixion, woodcut by Albrecht Durer"},
    "glorious" =>
      {"/images/woodcuts/resurrection-durer.jpg", "The Resurrection, woodcut by Albrecht Durer"},
    "luminous" =>
      {"/images/woodcuts/baptism-dore.jpg", "The Baptism of Jesus, engraving by Gustave Dore"},
    "seven_sorrows" =>
      {"/images/woodcuts/lamentation-durer.jpg", "The Lamentation, woodcut by Albrecht Durer"}
  }

  @impl true
  def mount(%{"category" => category}, _session, socket) do
    unless category in Categories.slugs() do
      raise LumenViaeWeb.NotFoundError, message: "unknown mystery category: #{category}"
    end

    actor = socket.assigns.current_admin
    sets = Rosary.list_visible_meditation_sets_by_category!(category, actor: actor)
    mysteries = Rosary.list_mysteries_by_category!(category, actor: actor, load: [:artwork])

    {:ok,
     socket
     |> assign(:category, category)
     |> assign(:title, category_title(category))
     |> assign(:subtitle, Categories.subtitle(category))
     |> assign(
       :days,
       LiturgicalCalendar.days_in_words(@calendar_categories[category], :traditional)
     )
     |> assign(:mysteries, mystery_rows(category, mysteries))
     |> assign(:painting, painting(category, mysteries, actor))
     |> assign(:meditation_sets, sets)
     |> assign(:kinds_offered, Filtering.kinds_offered(sets))
     |> assign(:voices, Voices.list())
     |> assign(:choices, PrayLinks.defaults())
     |> PageMeta.put("/mysteries/#{category}",
       title: category_title(category),
       description: category_description(category),
       image: PageMeta.category_image(category),
       trail: [{category_title(category), "/mysteries/#{category}"}]
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = Filtering.from_params(params)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:shown_sets, Filtering.apply_filters(socket.assigns.meditation_sets, filters))}
  end

  @impl true
  def handle_event("choose", %{"choices" => params}, socket) do
    choices = PrayLinks.merge(socket.assigns.choices, params)

    {:noreply,
     socket
     |> assign(:choices, choices)
     |> push_event("store_choices", PrayLinks.to_storage(choices))}
  end

  def handle_event("restore_choices", params, socket) do
    {:noreply, assign(socket, :choices, PrayLinks.merge(socket.assigns.choices, params))}
  end

  def handle_event("toggle_kind", %{"kind" => kind}, socket) do
    {:noreply, patch_filters(socket, Filtering.toggle_kind(socket.assigns.filters, kind))}
  end

  def handle_event("toggle_narrated", _params, socket) do
    filters = socket.assigns.filters
    {:noreply, patch_filters(socket, %{filters | narrated: not filters.narrated})}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, patch_filters(socket, %{kinds: [], narrated: false})}
  end

  def handle_event("providence", _params, socket) do
    case providence_pool(socket.assigns) do
      [] ->
        {:noreply, socket}

      sets ->
        set = Enum.random(sets)
        {:noreply, push_navigate(socket, to: PrayLinks.set_path(set.id, socket.assigns.choices))}
    end
  end

  # Providence chooses among the sets showing, or among all of them when
  # the filters leave none.
  defp providence_pool(%{shown_sets: [], meditation_sets: sets}), do: sets
  defp providence_pool(%{shown_sets: sets}), do: sets

  defp patch_filters(socket, filters) do
    path =
      case Filtering.to_params(filters) do
        [] -> "/mysteries/#{socket.assigns.category}"
        params -> "/mysteries/#{socket.assigns.category}?" <> URI.encode_query(params)
      end

    push_patch(socket, to: path, replace: true)
  end

  # One row per mystery the category has, in prayer order: the mystery's
  # own name and fruit where the table has them, its ordinal label always.
  defp mystery_rows(category, mysteries) do
    by_order = Map.new(mysteries, &{&1.order, &1})

    for order <- 1..Categories.mystery_count(category) do
      mystery = Map.get(by_order, order)

      %{
        order: order,
        label: Categories.mystery_label(category, order),
        name: mystery && mystery.name,
        fruit: mystery && mystery.fruit
      }
    end
  end

  # The painting the app's card shows for the category (its first
  # mystery's, or the Seven Sorrows' own card), else the woodcut.
  defp painting(category, mysteries, actor) do
    artwork =
      case Categories.card_mystery_key(category) do
        nil ->
          card = Rosary.get_category_card!(category, actor: actor, load: [:artwork])
          card && card.artwork

        _key ->
          mysteries |> Enum.find(&(&1.order == 1)) |> then(&(&1 && &1.artwork))
      end

    case artwork do
      %{url: url, alt: alt} when is_binary(url) ->
        %{src: url, alt: alt}

      _none ->
        @woodcuts |> Map.fetch!(category) |> then(fn {src, alt} -> %{src: src, alt: alt} end)
    end
  end

  defp category_title(category), do: PageMeta.category_title(category)

  defp category_description("joyful"),
    do:
      "Pray the Joyful Mysteries with meditations from the saints: the Annunciation, Visitation, Nativity, Presentation, and Finding in the Temple, with guided audio."

  defp category_description("sorrowful"),
    do:
      "Pray the Sorrowful Mysteries with meditations from the saints: the Agony in the Garden, Scourging, Crowning with Thorns, Carrying of the Cross, and Crucifixion, with guided audio."

  defp category_description("glorious"),
    do:
      "Pray the Glorious Mysteries with meditations from the saints: the Resurrection, Ascension, Descent of the Holy Ghost, Assumption, and Coronation of Our Lady, with guided audio."

  defp category_description("luminous"),
    do:
      "Pray the Luminous Mysteries with meditations from the saints: the Baptism of Our Lord, the wedding at Cana, the proclamation of the Kingdom, the Transfiguration, and the institution of the Eucharist."

  defp category_description("seven_sorrows"),
    do:
      "Pray the Seven Sorrows of Mary with meditations from the saints, from the prophecy of Simeon to the burial of Our Lord, with guided audio."
end
