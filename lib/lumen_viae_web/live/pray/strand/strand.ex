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
      %{decade: decade} -> "Mystery #{decade.index + 1} of #{length(sequence.decades)}"
    end
  end

  defp part_title(%{kind: :opening}), do: "The Opening Prayers"
  defp part_title(%{kind: :closing}), do: "The Closing Prayers"
  defp part_title(%{decade: decade}), do: decade.name

  defp part_note(_sequence, %{decade: nil} = page, _count), do: prayers_held(page)

  defp part_note(_sequence, %{decade: decade}, count),
    do: "Mystery #{decade.index + 1} of #{count}"

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

  @doc "The page's strand, the bead under the hand lit. Decorative: the status line says it in words."
  def beads(assigns) do
    page = Sequence.page(assigns.sequence, assigns.screen.page)
    assigns = assign(assigns, :page_kind, page.kind)

    ~H"""
    <div
      aria-hidden="true"
      class="prayer-words flex items-center justify-center gap-1.5 sm:gap-2 py-2"
    >
      <%= if @page_kind == :decade do %>
        <span class={bead_class(:large, @screen.bead == 0)}></span>
        <span class="w-2 h-px bg-gilt/30"></span>
        <span
          :for={n <- 1..@sequence.hail_marys}
          class={bead_class(:small, @screen.bead == n, @screen.bead > n)}
        ></span>
        <span class="w-2 h-px bg-gilt/30"></span>
        <span class={bead_class(:diamond, @screen.bead == @sequence.hail_marys + 1)}></span>
      <% else %>
        <.cross lit={@screen.place == "cross"} />
        <span class="w-2 h-px bg-gilt/30"></span>
        <span class={bead_class(:large, @screen.place == "large_bead")}></span>
        <span
          :for={n <- 1..3}
          class={bead_class(:small, @screen.place == "small_bead_#{n}")}
        ></span>
        <span class={bead_class(:diamond, @screen.place == "chain")}></span>
        <span class="w-2 h-px bg-gilt/30"></span>
        <.medal lit={@screen.place == "medal"} />
      <% end %>
    </div>
    """
  end

  defp bead_class(shape, lit, said \\ false) do
    base = "block shrink-0 border motion-safe:transition-all motion-safe:duration-300"

    size =
      case shape do
        :large -> "w-4 h-4 rounded-full"
        :small -> "w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-full"
        :diamond -> "w-2.5 h-2.5 rotate-45"
      end

    tone =
      cond do
        lit -> "bg-gilt border-gilt-light shadow-gilt scale-125"
        said -> "bg-gilt/55 border-night-line"
        true -> "bg-transparent border-night-line"
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

  defp medal(assigns) do
    ~H"""
    <span
      aria-hidden="true"
      class={[
        "block w-3 h-4 rounded-[50%] border shrink-0",
        if(@lit, do: "bg-gilt border-gilt-light shadow-gilt", else: "border-night-line")
      ]}
    ></span>
    """
  end

  @doc "What a page is called, for its button and the line under the strand."
  def page_name(%{kind: :opening}), do: "the opening prayers"
  def page_name(%{kind: :closing}), do: "the closing prayers"
  def page_name(%{decade: decade}), do: decade.label || decade.name
end
