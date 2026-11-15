defmodule LumenViaeWeb.Live.Prayers.Prayer.Novena do
  @moduledoc """
  A novena on its twin's page, one day at a time, as the app's novena
  (option A, 15 Nov 2026): the days as a row of numbered chips under the
  title, each a link (`?day=3`, so it works without JavaScript and can be
  shared), the day's number and title, its parts in order
  (`LumenViaeWeb.Live.Prayers.Novena.blocks/2`) and the way to the day
  before and the day after. A novena that prays the same every day (St
  Andrew) has no chips: the one day stands alone.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Prayers.Novena

  import LumenViaeWeb.Live.Prayers.Prayer.Text

  attr :novena, :map, required: true
  attr :prayer_id, :string, required: true
  attr :day, :integer, required: true
  attr :blocks, :list, required: true

  def novena_day(assigns) do
    assigns =
      assigns
      |> assign(:count, length(assigns.novena.days))
      |> assign(:same?, Novena.same_every_day?(assigns.novena))
      |> assign(:current, Novena.day(assigns.novena, assigns.day))

    ~H"""
    <div data-role="novena">
      <p class="mt-6 font-garamond italic text-lg md:text-xl text-ink-muted leading-relaxed max-w-[62ch]">
        {Novena.intro(@novena)}
      </p>

      <nav
        :if={not @same?}
        id="novena-days"
        class="novena-days mt-6"
        aria-label="Day of the novena"
        data-role="novena-days"
      >
        <.link
          :for={n <- 1..@count}
          patch={Novena.day_path(@prayer_id, n)}
          class="novena-day-chip"
          aria-current={if(n == @day, do: "page")}
          aria-label={"Day #{n}"}
          data-role="day-chip"
        >
          <span aria-hidden="true">{n}</span>
        </.link>
      </nav>

      <section
        id="novena-day"
        class="mt-8"
        aria-labelledby="novena-day-heading"
        data-role="novena-day"
      >
        <p class="kicker" data-role="day-count">
          {if(@same?, do: "Each of the #{@count} days", else: "Day #{@day} of #{@count}")}
        </p>
        <h2
          id="novena-day-heading"
          class="mt-1 font-display text-2xl md:text-[1.75rem] text-ink-light leading-tight"
        >
          {if(@same?, do: "Every day", else: @current.title)}
        </h2>

        <div class="mt-6 space-y-8">
          <.block :for={block <- @blocks} block={block} />
        </div>
      </section>

      <nav
        :if={not @same?}
        class="mt-12 flex items-center justify-between gap-4"
        aria-label="The day before and after"
      >
        <.link
          :if={@day > 1}
          patch={Novena.day_path(@prayer_id, @day - 1) <> "#novena-days"}
          class="btn-outline-gold"
          rel="prev"
        >
          <span aria-hidden="true">&lsaquo;</span> Day {@day - 1}
        </.link>
        <span :if={@day == 1} />
        <.link
          :if={@day < @count}
          patch={Novena.day_path(@prayer_id, @day + 1) <> "#novena-days"}
          class="btn-gold"
          rel="next"
        >
          Day {@day + 1} <span aria-hidden="true">&rsaquo;</span>
        </.link>
      </nav>
    </div>
    """
  end

  attr :block, :map, required: true

  defp block(%{block: %{type: :prayer}} = assigns) do
    ~H"""
    <div data-role="novena-part">
      <h3 :if={@block.heading} class="kicker !text-ink-muted mb-3">{@block.heading}</h3>
      <p :if={Novena.times_phrase(@block.times)} class="book-text mb-2">
        <span class="book-rubric">Said {Novena.times_phrase(@block.times)}.</span>
      </p>
      <p :if={@block.instead} class="book-text mb-2">
        <span class="book-rubric">
          Or, in its place, <.link
            navigate={"/prayers/" <> @block.instead.id}
            class="underline underline-offset-2"
          >
            {lower_article(@block.instead.title)}</.link>.
        </span>
      </p>
      <.prayer_text stanzas={@block.stanzas} language="english" />
    </div>
    """
  end

  defp block(%{block: %{type: :said}} = assigns) do
    ~H"""
    <p class="book-text" data-role="novena-direction">
      <span class="book-rubric">{said_line(@block.items)}</span>
    </p>
    """
  end

  # The decades link to Today's Rosary, so someone who doesn't know them by
  # heart can pray them (design, 15 Nov); it opens in the same tab.
  defp block(%{block: %{type: :rosary}} = assigns) do
    assigns = assign(assigns, :lead, String.replace_suffix(assigns.block.text, "the Rosary.", ""))

    ~H"""
    <p class="book-text" data-role="novena-direction">
      <span :if={@lead != @block.text} class="book-rubric">
        {@lead}<.link navigate="/" class="underline underline-offset-2">the Rosary</.link>.
      </span>
      <span :if={@lead == @block.text} class="book-rubric">{@block.text}</span>
    </p>
    """
  end

  # Built as one run of markup, not a template, so no space falls before
  # a comma: "The Our Father nine times and the Hail Mary nine times."
  defp said_line(items) do
    last = length(items) - 1

    pieces =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, i} ->
        title = if i == 0, do: item.prayer.title, else: lower_article(item.prayer.title)

        [
          separator(i, last),
          ~s(<a href="/prayers/),
          escape(item.prayer.id),
          ~s(" data-phx-link="redirect" data-phx-link-state="push" class="underline underline-offset-2">),
          escape(title),
          "</a>",
          escape(times_suffix(item.times))
        ]
      end)

    {:safe, [pieces, "."]}
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp separator(0, _last), do: ""
  defp separator(i, i), do: " and "
  defp separator(_i, _last), do: ", "

  defp times_suffix(times) do
    case Novena.times_phrase(times) do
      nil -> ""
      phrase -> " " <> phrase
    end
  end

  defp lower_article("The " <> rest), do: "the " <> rest
  defp lower_article(title), do: title
end
