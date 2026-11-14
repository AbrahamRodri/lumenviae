defmodule LumenViaeWeb.Live.Pray.Strand do
  @moduledoc """
  Where the reader is in the Rosary: `where/1`, the pill that names the
  part with a dot a part under it, and `go_to_list/1`, the list it opens,
  a way to each part; and `beads/1`, the strand of the page counted on the
  screen with the bead under the hand lit.
  """
  use LumenViaeWeb, :html

  alias Phoenix.LiveView.JS

  alias LumenViaeWeb.Live.Pray.Sequence

  attr :sequence, :map, required: true
  attr :page, :integer, required: true
  attr :open, :boolean, default: false

  @doc """
  Where the reader is, as one pill: "Opening Prayers", "Mystery 2 of 5" or
  "Closing Prayers", with a dot a part under it, the current one gilt.
  Pressing it opens the Go to list (`go_to_list/1`).
  """
  def where(assigns) do
    assigns = assign(assigns, :label, where_label(assigns.sequence, assigns.page))

    ~H"""
    <div class="flex flex-col items-center">
      <button
        id="go-to-toggle"
        type="button"
        phx-click="toggle_go_to"
        aria-expanded={to_string(@open)}
        aria-controls="prayer-go-to"
        class="prayer-where flex items-center justify-center gap-1.5 sm:gap-2 min-h-11 px-3.5 sm:px-5 rounded-full border border-night-border bg-night-raised text-gilt kicker !tracking-[0.14em] sm:!tracking-[0.2em] whitespace-nowrap hover:border-gilt motion-safe:transition-colors"
      >
        <span>{@label}</span>
        <span
          class={[
            "hero-chevron-down size-4 motion-safe:transition-transform",
            @open && "rotate-180"
          ]}
          aria-hidden="true"
        />
      </button>
      <ol aria-hidden="true" class="flex items-center justify-center gap-1.5 -mt-1 pb-1">
        <li
          :for={page <- @sequence.pages}
          class={[
            "block h-1.5 rounded-full motion-safe:transition-all motion-safe:duration-300",
            if(page.index == @page, do: "w-5 bg-gilt", else: "w-1.5 bg-night-line")
          ]}
        >
        </li>
      </ol>
    </div>
    """
  end

  # Closing the list puts focus back on the toggle that opened it, rather
  # than letting it fall to the page (WCAG 2.4.3).
  defp close_go_to, do: JS.push("close_go_to") |> JS.focus(to: "#go-to-toggle")

  attr :sequence, :map, required: true
  attr :page, :integer, required: true
  attr :heading, :string, required: true

  @doc """
  The Go to list under the header: the set's name, then a row for each
  part of the Rosary, the one the reader is in saying "Here". A row sends
  `go_to` with its page.
  """
  def go_to_list(assigns) do
    assigns = assign(assigns, :count, length(assigns.sequence.decades))

    ~H"""
    <div
      id="prayer-go-to"
      phx-window-keydown={close_go_to()}
      phx-key="Escape"
      class="mt-3 rounded-2xl border border-night-border bg-night-raised px-2 py-4 sm:px-4"
    >
      <p class="kicker px-3">Go to</p>
      <p class="px-3 mt-1 font-display text-2xl text-ink-light leading-tight">{@heading}</p>
      <ul class="mt-3">
        <li :for={page <- @sequence.pages} class="border-t border-night-border first:border-t-0">
          <button
            type="button"
            phx-click={JS.push("go_to") |> JS.focus(to: "#go-to-toggle")}
            phx-value-page={page.index}
            aria-current={if page.index == @page, do: "step", else: "false"}
            class={[
              "flex items-center gap-3 w-full min-h-14 px-3 py-2 rounded-xl text-left hover:bg-gilt/10",
              page.index == @page && "bg-gilt/15"
            ]}
          >
            <span class="min-w-0 flex-1">
              <span class="block font-display text-xl text-ink-light leading-snug">
                {part_title(page)}
              </span>
              <span class="block font-garamond text-base italic text-ink-muted leading-snug">
                {part_note(@sequence, page, @count)}
              </span>
            </span>
            <span :if={page.index == @page} class="kicker text-gilt shrink-0">Here</span>
          </button>
        </li>
      </ul>
    </div>
    """
  end

  defp where_label(sequence, page) do
    case Sequence.page(sequence, page) do
      %{kind: :opening} -> "Opening Prayers"
      %{kind: :closing} -> "Closing Prayers"
      %{decade: decade} -> place(sequence, decade, length(sequence.decades))
    end
  end

  defp part_title(%{kind: :opening}), do: "The Opening Prayers"
  defp part_title(%{kind: :closing}), do: "The Closing Prayers"
  defp part_title(%{decade: decade}), do: decade.name

  defp part_note(_sequence, %{decade: nil} = page, _count), do: prayers_held(page)

  defp part_note(sequence, %{decade: decade}, count), do: place(sequence, decade, count)

  # "Mystery 2 of 5", or on the Seven Sorrows "Sorrow 2 of 7".
  defp place(%{category: "seven_sorrows"}, decade, count),
    do: "Sorrow #{decade.index + 1} of #{count}"

  defp place(_sequence, decade, count), do: "Mystery #{decade.index + 1} of #{count}"

  # The prayers a part holds in words, in the order they are said, as the
  # script gives them: "The Sign of the Cross, the Creed, an Our Father,
  # three Hail Marys and the Glory Be".
  defp prayers_held(page) do
    page.screens
    |> Enum.filter(&(&1.kind == :prayer))
    |> Enum.map(& &1.prayer_id)
    |> Enum.chunk_by(& &1)
    |> Enum.map(&prayer_phrase(hd(&1), length(&1)))
    |> join_phrases()
    |> upcase_first()
  end

  defp prayer_phrase("sign_of_cross", _n), do: "the Sign of the Cross"
  defp prayer_phrase("apostles_creed", _n), do: "the Creed"
  defp prayer_phrase("our_father", 1), do: "an Our Father"
  defp prayer_phrase("our_father", n), do: "#{count_word(n)} Our Fathers"
  defp prayer_phrase("hail_mary", 1), do: "a Hail Mary"
  defp prayer_phrase("hail_mary", n), do: "#{count_word(n)} Hail Marys"
  defp prayer_phrase("glory_be", _n), do: "the Glory Be"

  defp prayer_phrase(id, _n) do
    case Sequence.prayer_title(id) do
      "The " <> rest -> "the " <> rest
      nil -> String.replace(id, "_", " ")
      title -> title
    end
  end

  defp count_word(n) do
    Enum.at(~w(none one two three four five six seven eight nine ten), n) || Integer.to_string(n)
  end

  defp join_phrases([one]), do: one
  defp join_phrases([a, b]), do: "#{a} and #{b}"

  defp join_phrases(phrases),
    do: Enum.join(Enum.drop(phrases, -1), ", ") <> " and " <> List.last(phrases)

  defp upcase_first(""), do: ""

  defp upcase_first(<<first::utf8, rest::binary>>),
    do: String.upcase(<<first::utf8>>) <> rest

  attr :sequence, :map, required: true
  attr :screen, :map, required: true

  @doc """
  The bead rail beside the words, as the app's: a thin gold line down the
  right of the prayer with the beads on it, about five of a decade around
  the one under the hand, which is larger and glows, with its Hail Mary's
  number beside it. Beads already prayed are pale outlines, those to come
  gold dots. The opening prayers show the pendant's beads with the cross at
  the foot, and the closing prayers the medal. Decorative: `#bead-status`
  says it in words.
  """
  def beads(assigns) do
    page = Sequence.page(assigns.sequence, assigns.screen.page)
    assigns = assign(assigns, :beads, rail(page.kind, assigns.sequence, assigns.screen))

    ~H"""
    <div
      id="bead-rail"
      aria-hidden="true"
      class="prayer-words relative flex flex-col items-center gap-3 w-11 py-2"
    >
      <span class="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-gilt/30"></span>
      <span
        :for={bead <- @beads}
        data-bead={bead.id}
        data-state={bead.state}
        class="relative flex items-center justify-center"
      >
        <span
          :if={bead.number}
          class="absolute right-full mr-1.5 font-garamond text-xs text-gilt tabular-nums"
        >
          {bead.number}
        </span>
        <%= case bead.shape do %>
          <% :cross -> %>
            <.cross lit={bead.state == :current} />
          <% :medal -> %>
            <.medal lit={bead.state == :current} />
          <% shape -> %>
            <span class={bead_class(shape, bead.state)}></span>
        <% end %>
      </span>
    </div>
    """
  end

  # The beads the rail shows, top to bottom, each with its state.
  defp rail(:decade, sequence, screen) do
    last = sequence.hail_marys + 1

    beads =
      for n <- 0..last do
        shape =
          cond do
            n == 0 -> :large
            n == last -> :diamond
            true -> :small
          end

        %{
          id: "decade-#{n}",
          shape: shape,
          state: state(n, screen.bead),
          number: if(shape == :small and n == screen.bead, do: n)
        }
      end

    # About five around the bead under the hand.
    first = min(max(screen.bead - 2, 0), max(length(beads) - 5, 0))
    Enum.slice(beads, first, 5)
  end

  defp rail(:closing, _sequence, _screen),
    do: [%{id: "medal", shape: :medal, state: :current, number: nil}]

  # The pendant from the top down: the chain's Glory Be, the three small
  # beads, the large bead, and the cross at the foot, where it begins.
  defp rail(_opening, _sequence, screen) do
    order = ~w(cross large_bead small_bead_1 small_bead_2 small_bead_3 chain)
    at = Enum.find_index(order, &(&1 == screen.place)) || 0

    order
    |> Enum.with_index()
    |> Enum.map(fn {place, i} ->
      shape =
        case place do
          "cross" -> :cross
          "large_bead" -> :large
          "chain" -> :diamond
          _small -> :small
        end

      %{id: place, shape: shape, state: state(i, at), number: nil}
    end)
    |> Enum.reverse()
  end

  defp state(n, at) when n < at, do: :said
  defp state(n, at) when n == at, do: :current
  defp state(_n, _at), do: :to_come

  defp bead_class(shape, state) do
    base = "block shrink-0 motion-safe:transition-all motion-safe:duration-300"

    size =
      case {shape, state} do
        {:large, :current} -> "w-5 h-5 rounded-full"
        {:large, _} -> "w-3.5 h-3.5 rounded-full"
        {:small, :current} -> "w-4 h-4 rounded-full"
        {:small, _} -> "w-2.5 h-2.5 rounded-full"
        {:diamond, :current} -> "w-3.5 h-3.5 rotate-45"
        {:diamond, _} -> "w-2.5 h-2.5 rotate-45"
      end

    tone =
      case state do
        :current -> "bg-gilt border border-gilt-light shadow-gilt"
        :said -> "bg-night border border-ink-light/70"
        :to_come -> "bg-gilt/70"
      end

    [base, size, tone]
  end

  attr :lit, :boolean, default: false

  defp cross(assigns) do
    ~H"""
    <svg
      viewBox="0 0 9 13"
      aria-hidden="true"
      class={["w-3 h-4 shrink-0", if(@lit, do: "fill-gilt", else: "fill-night-line")]}
    >
      <path d="M3.24 0 H5.76 V2.64 H9 V5.16 H5.76 V13 H3.24 V5.16 H0 V2.64 H3.24 Z" />
    </svg>
    """
  end

  attr :lit, :boolean, default: false

  # The pendant's medal, with a small cross on it, as the app draws it.
  defp medal(assigns) do
    ~H"""
    <span
      aria-hidden="true"
      class={[
        "flex items-center justify-center w-5 h-6 rounded-[50%] border shrink-0",
        if(@lit, do: "bg-gilt border-gilt-light shadow-gilt", else: "border-night-line")
      ]}
    >
      <svg
        viewBox="0 0 9 13"
        class={["w-2 h-3", if(@lit, do: "fill-night", else: "fill-night-line")]}
      >
        <path d="M3.24 0 H5.76 V2.64 H9 V5.16 H5.76 V13 H3.24 V5.16 H0 V2.64 H3.24 Z" />
      </svg>
    </span>
    """
  end

  @doc "What a page is called, for its button and the line under the strand."
  def page_name(%{kind: :opening}), do: "the opening prayers"
  def page_name(%{kind: :closing}), do: "the closing prayers"
  def page_name(%{decade: decade}), do: decade.label || decade.name
end
