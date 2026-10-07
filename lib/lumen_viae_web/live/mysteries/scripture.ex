defmodule LumenViaeWeb.Live.Mysteries.Scripture do
  @moduledoc """
  The mysteries in Scripture: every mystery of the Rosary and the Seven
  Sorrows, with its Douay-Rheims passages.

  Each mystery's name, fruit and scripture reference come from the
  database, which is what the iOS app shows; the partials own only what is
  this page's: a one-line summary of each mystery and its passages.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Rosary

  embed_templates "_partials/*"

  @categories [
    %{id: "joyful", name: "Joyful", pray: "Pray the Joyful Mysteries"},
    %{id: "sorrowful", name: "Sorrowful", pray: "Pray the Sorrowful Mysteries"},
    %{id: "glorious", name: "Glorious", pray: "Pray the Glorious Mysteries"},
    %{id: "luminous", name: "Luminous", pray: "Pray the Luminous Mysteries"},
    %{id: "seven_sorrows", name: "Seven Sorrows", pray: "Pray the Seven Sorrows"}
  ]

  @impl true
  def mount(params, _session, socket) do
    selected_category =
      params
      |> Map.get("category", "joyful")
      |> validate_category()

    socket =
      socket
      |> assign(page_title: "Finding the Mysteries in Scripture")
      |> assign(
        meta_description:
          "Read the scriptural accounts behind every mystery of the Holy Rosary and the Seven Sorrows of Mary, with Douay-Rheims passages and the traditional fruit of each mystery."
      )
      |> assign(categories: @categories, selected_category: selected_category)
      |> assign(mysteries: mysteries_by_category(socket.assigns.current_admin))

    {:ok, socket}
  end

  @impl true
  def handle_event("select-category", %{"id" => category_id}, socket) do
    selected_category = validate_category(category_id, socket.assigns.selected_category)

    {:noreply, assign(socket, :selected_category, selected_category)}
  end

  # %{"joyful" => %{1 => %Mystery{}, ...}, ...}: a partial looks its
  # mysteries up by their place in the category.
  defp mysteries_by_category(actor) do
    [actor: actor]
    |> Rosary.list_mysteries!()
    |> Enum.group_by(& &1.category)
    |> Map.new(fn {category, mysteries} -> {category, Map.new(mysteries, &{&1.order, &1})} end)
  end

  @doc """
  One mystery on the page: its name, reference and fruit from the database,
  the page's own summary, its passages behind a disclosure, and a link to
  its category's page to pray it. Renders nothing for a mystery the
  database does not have.
  """
  attr :mystery, :map, default: nil
  attr :category, :string, required: true
  slot :summary, required: true
  slot :passage, required: true

  def mystery_card(assigns) do
    assigns = assign(assigns, :pray, Enum.find(@categories, &(&1.id == assigns.category)).pray)

    ~H"""
    <article
      :if={@mystery}
      id={"mystery-#{@category}-#{@mystery.order}"}
      class="hairline-card p-5 md:p-7 transition-colors duration-300 hover:border-gold/60"
    >
      <h3 class="font-cinzel text-navy text-xl lg:text-2xl mb-1 md:mb-2">
        {@mystery.order}. {@mystery.name}
      </h3>
      <p class="font-garamond text-brown italic leading-relaxed text-lg md:text-xl mb-3 max-w-[65ch]">
        {render_slot(@summary)}
      </p>
      <p
        :if={@mystery.fruit}
        class="font-cinzel text-xs tracking-[0.25em] uppercase text-gold-dark"
      >
        Fruit of the Mystery: {@mystery.fruit}
      </p>
      <p :if={@mystery.scripture_reference} class="font-garamond text-brown-light italic">
        {@mystery.scripture_reference}
      </p>
      <details class="mt-1">
        <summary class="min-h-11 flex items-center font-cinzel text-xs text-gold-dark cursor-pointer hover:text-navy uppercase tracking-[0.15em] transition-colors duration-300">
          Read the Scripture
        </summary>
        {render_slot(@passage)}
      </details>
      <p class="mt-3 border-t border-gold/20 pt-1 text-right">
        <.link
          navigate={"/mysteries/#{@category}"}
          class="inline-flex items-center gap-2 min-h-11 font-cinzel text-xs tracking-[0.15em] uppercase text-navy hover:text-gold-dark transition-colors"
        >
          {@pray}
          <svg
            viewBox="0 0 24 24"
            class="w-3.5 h-3.5"
            fill="none"
            stroke="currentColor"
            aria-hidden="true"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
        </.link>
      </p>
    </article>
    """
  end

  defp validate_category(category_id, default \\ "joyful") do
    case Enum.find(@categories, &(&1.id == category_id)) do
      nil -> default
      _ -> category_id
    end
  end
end
