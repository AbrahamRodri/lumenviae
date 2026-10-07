defmodule LumenViaeWeb.Live.Pray.Strand do
  @moduledoc """
  Where the reader is in the Rosary, drawn: `progress/1`, the whole
  Rosary as the pendant, a bead per decade and the medal, each a way to
  that page; and `beads/1`, the strand of the page counted on the screen
  with the bead under the hand lit.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Pray.Sequence

  attr :sequence, :map, required: true
  attr :page, :integer, required: true

  def progress(assigns) do
    ~H"""
    <nav aria-label="The Rosary's parts" class="max-w-sm mx-auto">
      <ol class="relative flex items-center justify-center">
        <li
          :for={page <- @sequence.pages}
          class="relative flex items-center"
        >
          <button
            type="button"
            phx-click="go_to"
            phx-value-page={page.index}
            aria-label={"Go to " <> page_name(page)}
            aria-current={if page.index == @page, do: "step", else: "false"}
            class="group flex items-center justify-center w-9 h-11 rounded-full focus-visible:outline-2 focus-visible:outline-offset-0 focus-visible:outline-gold"
          >
            <span
              :if={page.kind == :decade}
              aria-hidden="true"
              class={[
                "block rounded-full border motion-safe:transition-all motion-safe:duration-300",
                cond do
                  page.index == @page -> "w-3.5 h-3.5 bg-gold border-gold-light shadow-glow"
                  page.index < @page -> "w-2.5 h-2.5 bg-gold/60 border-gold/50 group-hover:bg-gold/90"
                  true -> "w-2.5 h-2.5 bg-navy border-gold/50 group-hover:bg-gold/30"
                end
              ]}
            ></span>
            <.cross :if={page.kind == :opening} lit={page.index == @page} />
            <.medal :if={page.kind == :closing} lit={page.index == @page} />
          </button>
        </li>
      </ol>
      <p class="mt-1 font-cinzel text-[0.65rem] tracking-[0.25em] uppercase text-center text-gold-light/70">
        {position_label(@sequence, @page)}
      </p>
    </nav>
    """
  end

  attr :sequence, :map, required: true
  attr :screen, :map, required: true

  @doc "The page's strand, the bead under the hand lit. Decorative: the status line says it in words."
  def beads(assigns) do
    page = Sequence.page(assigns.sequence, assigns.screen.page)
    assigns = assign(assigns, :page_kind, page.kind)

    ~H"""
    <div aria-hidden="true" class="flex items-center justify-center gap-1.5 sm:gap-2 py-2">
      <%= if @page_kind == :decade do %>
        <span class={bead_class(:large, @screen.bead == 0)}></span>
        <span class="w-2 h-px bg-gold/30"></span>
        <span
          :for={n <- 1..@sequence.hail_marys}
          class={bead_class(:small, @screen.bead == n, @screen.bead > n)}
        ></span>
        <span class="w-2 h-px bg-gold/30"></span>
        <span class={bead_class(:diamond, @screen.bead == @sequence.hail_marys + 1)}></span>
      <% else %>
        <.cross lit={@screen.place == "cross"} />
        <span class="w-2 h-px bg-gold/30"></span>
        <span class={bead_class(:large, @screen.place == "large_bead")}></span>
        <span
          :for={n <- 1..3}
          class={bead_class(:small, @screen.place == "small_bead_#{n}")}
        ></span>
        <span class={bead_class(:diamond, @screen.place == "chain")}></span>
        <span class="w-2 h-px bg-gold/30"></span>
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
        lit -> "bg-gold border-gold-light shadow-glow scale-125"
        said -> "bg-gold/55 border-gold/50"
        true -> "bg-transparent border-gold/45"
      end

    [base, size, tone]
  end

  attr :lit, :boolean, default: false

  defp cross(assigns) do
    ~H"""
    <svg
      viewBox="0 0 9 13"
      aria-hidden="true"
      class={["w-3 h-4 shrink-0", if(@lit, do: "fill-gold", else: "fill-gold/45")]}
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
        if(@lit, do: "bg-gold border-gold-light shadow-glow", else: "border-gold/50")
      ]}
    ></span>
    """
  end

  @doc "What a page is called, for its button and the line under the strand."
  def page_name(%{kind: :opening}), do: "the opening prayers"
  def page_name(%{kind: :closing}), do: "the closing prayers"
  def page_name(%{decade: decade}), do: decade.label || decade.name

  defp position_label(sequence, page) do
    case Sequence.page(sequence, page) do
      %{kind: :opening} ->
        "The Opening Prayers"

      %{kind: :closing} ->
        "The Closing Prayers"

      %{decade: decade} ->
        noun = if sequence.chaplet?, do: "Sorrow", else: "Mystery"
        "#{noun} #{roman(decade.index + 1)} of #{roman(length(sequence.decades))}"
    end
  end

  @doc "Roman numerals for the decades, one to twenty."
  def roman(n) when n in 1..20 do
    Enum.at(
      ~w(I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX),
      n - 1
    )
  end

  def roman(n), do: Integer.to_string(n)
end
