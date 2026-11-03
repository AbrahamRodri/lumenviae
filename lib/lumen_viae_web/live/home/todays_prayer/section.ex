defmodule LumenViaeWeb.Live.Home.TodaysPrayer.Section do
  @moduledoc """
  "Today's Prayer" as the home page draws it, the app's
  `TodaysPrayerRowView`: the heading with the visitor's date beside it,
  then the rows as a ruled list (two columns from 1024px), each a link
  with its painting cut square on a gold hairline, its name, its line and
  its fact, a seal on the painting once prayed, the lit hour before the
  Office's fact and the day's silk, in its vestment colour, before the
  Mass's.

  A row whose source has not spoken yet (the browser's plan, the
  browser's clock) is an empty frame of its size, so nobody is shown the
  hour in UTC or a plan that is not theirs.
  """
  use LumenViaeWeb, :html

  import LumenViaeWeb.Live.Prayers.Painting

  alias LumenViaeWeb.Live.Home.TodaysPrayer

  attr :date, :any, default: nil, doc: "the visitor's date, nil until the clock is known"
  attr :rows, :list, required: true, doc: "each a row, or `{:waiting, id}`"

  def section(assigns) do
    ~H"""
    <section
      id="todays-prayer"
      phx-hook="ConsecrationPlan"
      class="px-4 sm:px-8 py-12 md:py-16"
      aria-labelledby="todays-prayer-heading"
    >
      <div class="max-w-6xl mx-auto">
        <div class="todays-prayer__head">
          <h2 id="todays-prayer-heading" class="section-heading">Today's Prayer</h2>
          <p :if={@date} class="todays-prayer__date" data-role="todays-prayer-date">
            <span class="sr-only">{Calendar.strftime(@date, "%A, %B %-d")}</span>
            <span aria-hidden="true">{TodaysPrayer.date_line(@date)}</span>
          </p>
        </div>

        <ul class="todays-prayer__list" aria-label="Today's Prayer">
          <li :for={row <- @rows} id={"todays-prayer-#{row_id(row)}"}>
            <.row row={row} />
          </li>
        </ul>
      </div>
    </section>
    """
  end

  defp row_id({:waiting, id}), do: id
  defp row_id(%{id: id}), do: id

  attr :row, :any, required: true

  defp row(%{row: {:waiting, _id}} = assigns) do
    ~H"""
    <div class="todays-prayer__row todays-prayer__row--waiting" data-role="waiting" aria-hidden="true">
      <span class="todays-prayer__painting"></span>
    </div>
    """
  end

  defp row(assigns) do
    ~H"""
    <.link
      navigate={@row.path}
      class="row-link todays-prayer__row home-row"
      aria-label={@row.spoken}
      data-role={"row-#{@row.id}"}
      data-prayed={to_string(@row.prayed?)}
    >
      <span class="todays-prayer__painting" aria-hidden="true">
        <.painting painting={@row.painting} sizes="64px" class="w-full h-full object-cover" />
        <span :if={@row.prayed?} class="todays-prayer__seal" data-role="prayed-seal">
          <span class="hero-check-badge-solid size-4"></span>
        </span>
      </span>
      <span class="flex-1 min-w-0" aria-hidden="true">
        <span class="row-title">{@row.name}</span>
        <span class="todays-prayer__line">{@row.subtitle}</span>
        <span class="todays-prayer__fact">
          <span :if={@row.mark == :lit_hour} class="todays-prayer__lit"></span>
          <span
            :if={match?({:silk, _letter}, @row.mark)}
            class={["missal-silk", "missal-silk--#{elem(@row.mark, 1)}"]}
            data-role="silk"
          ></span>
          {@row.fact || raw("&nbsp;")}
        </span>
      </span>
      <span class="hero-chevron-right size-5 row-chevron" aria-hidden="true" />
    </.link>
    """
  end
end
