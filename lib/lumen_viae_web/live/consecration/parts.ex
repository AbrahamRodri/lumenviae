defmodule LumenViaeWeb.Live.Consecration.Parts do
  @moduledoc """
  The pieces the Consecration's pages share, each the twin of the app's:
  the introduction's kicker (`ConsecrationIntroKicker`) and fine rule
  (`ConsecrationIntroRule`), a card's engraved heading (`CardHeading`), a
  painting in the lancet arch (`ArchHero`, the threshold's Coronation), the
  phase's tinted ground (`ConsecrationPhaseBackground`), the seal of the
  completion, the quiet note honouring a finished consecration, and True
  Devotion laid on the page as a book.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Consecration.Days

  import LumenViaeWeb.Live.Prayers.Painting

  attr :class, :any, default: nil
  slot :inner_block, required: true

  def kicker(assigns) do
    ~H"""
    <p class={["cons-kicker", @class]}>{render_slot(@inner_block)}</p>
    """
  end

  attr :class, :any, default: nil

  def rule(assigns) do
    ~H"""
    <span class={["cons-rule", @class]} aria-hidden="true"></span>
    """
  end

  attr :title, :string, required: true
  attr :meta, :string, default: nil
  attr :level, :string, default: "h2"
  attr :id, :string, default: nil

  def card_heading(assigns) do
    ~H"""
    <div class="cons-card__heading">
      <.dynamic_tag tag_name={@level} id={@id} class="cons-card__title">{@title}</.dynamic_tag>
      <span :if={@meta} class="cons-card__meta">{@meta}</span>
    </div>
    """
  end

  @doc "A painting cut into the lancet arch, with its two gold rims."
  attr :painting, :any, required: true, doc: "`{name, focal x, focal y}`"
  attr :class, :any, default: nil
  attr :style, :string, default: nil
  attr :tinted, :boolean, default: false, doc: "lay the phase's hue over it (`--phase-*`)"

  def arch(assigns) do
    ~H"""
    <div class={["cons-arch", @class]} style={@style} aria-hidden="true">
      <div class="cons-arch__plate">
        <.painting painting={@painting} sizes="(min-width: 768px) 30rem, 90vw" loading="eager" />
        <span :if={@tinted} class="cons-arch__tint"></span>
      </div>
      <svg class="cons-arch__rim" viewBox="0 0 100 100" preserveAspectRatio="none">
        <path d="M0.5,100 L0.5,28 Q3.5,10.6 50,0.5 Q96.5,10.6 99.5,28 L99.5,100" />
        <path
          class="cons-arch__rim-inner"
          d="M2.6,100 L2.6,28.6 Q5.4,12.4 50,2.8 Q94.6,12.4 97.4,28.6 L97.4,100"
        />
      </svg>
    </div>
    """
  end

  @doc "The page's ground with a phase's tint over it, behind everything."
  attr :phase, :map, default: nil

  def ground(assigns) do
    ~H"""
    <div
      class="cons-ground"
      style={@phase && Days.tint_style(@phase)}
      data-phase={@phase && @phase.id}
      aria-hidden="true"
    >
    </div>
    """
  end

  @doc "One quiet line honouring a finished consecration."
  slot :inner_block, required: true

  def completed_note(assigns) do
    ~H"""
    <p class="cons-completed" data-role="completed-note">
      <.seal_glyph class="size-4 shrink-0" />
      <span>{render_slot(@inner_block)}</span>
    </p>
    """
  end

  attr :class, :any, default: nil

  def seal_glyph(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 256 256" fill="currentColor" aria-hidden="true">
      <path d="M225.86,102.82c-3.77-3.94-7.67-8-9.14-11.57-1.36-3.27-1.44-8.69-1.52-13.94-.15-9.76-.31-20.82-8-28.51s-18.75-7.85-28.51-8c-5.25-.08-10.67-.16-13.94-1.52-3.56-1.47-7.63-5.37-11.57-9.14C146.28,23.51,138.44,16,128,16s-18.27,7.51-25.18,14.14c-3.94,3.77-8,7.67-11.57,9.14C88,40.64,82.56,40.72,77.31,40.8c-9.76.15-20.82.31-28.51,8S41,67.55,40.8,77.31c-.08,5.25-.16,10.67-1.52,13.94-1.47,3.56-5.37,7.63-9.14,11.57C23.51,109.72,16,117.56,16,128s7.51,18.27,14.14,25.18c3.77,3.94,7.67,8,9.14,11.57,1.36,3.27,1.44,8.69,1.52,13.94.15,9.76.31,20.82,8,28.51s18.75,7.85,28.51,8c5.25.08,10.67.16,13.94,1.52,3.56,1.47,7.63,5.37,11.57,9.14C109.72,232.49,117.56,240,128,240s18.27-7.51,25.18-14.14c3.94-3.77,8-7.67,11.57-9.14,3.27-1.36,8.69-1.44,13.94-1.52,9.76-.15,20.82-.31,28.51-8s7.85-18.75,8-28.51c.08-5.25.16-10.67,1.52-13.94,1.47-3.56,5.37-7.63,9.14-11.57C232.49,146.28,240,138.44,240,128S232.49,109.73,225.86,102.82Zm-52.2,6.84-56,56a8,8,0,0,1-11.32,0l-24-24a8,8,0,0,1,11.32-11.32L112,148.69l50.34-50.35a8,8,0,0,1,11.32,11.32Z" />
    </svg>
    """
  end

  @doc """
  True Devotion laid on the page as a book: its cloth beside its name and
  its author, opening its title page (`/true-devotion`, PR #149).
  """
  attr :heading, :string, default: "The book behind this consecration"

  def book_card(assigns) do
    ~H"""
    <.link navigate={Days.book_path()} class="cons-card cons-book" data-role="book">
      <.card_heading title={@heading} />
      <span class="cons-book__body">
        <span class="cons-book__cover" aria-hidden="true">
          <span class="cons-book__cross"></span>
        </span>
        <span class="cons-book__words">
          <span class="cons-book__title">True Devotion to Mary</span>
          <span class="cons-book__author">St. Louis de Montfort</span>
          <span class="cons-book__open">
            <span class="hero-book-open size-4" aria-hidden="true" /> Open the book
            <span class="hero-chevron-right size-3" aria-hidden="true" />
          </span>
        </span>
      </span>
    </.link>
    """
  end
end
