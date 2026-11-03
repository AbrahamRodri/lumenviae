defmodule LumenViaeWeb.Live.Chants.Parts do
  @moduledoc """
  The pieces every Chant page shares, as the app draws them: the dark play
  disc lit through a gold rim (`ChantPlayDisc`), a chant as a row with its
  own painting (`ChantPaintedRow`) or numbered on a shelf whose chants
  share one (`ChantNumberedRow`), a chant as a square card (`ChantSquareCard`),
  a section as a painted card (`ChantSectionsGrid`), the moving bars beside
  what sounds and the credit the recordings carry (`ChantCredit`).

  A tap on a chant's names opens its page; only the disc plays it, where
  it stands (`ChantTap`). The disc carries the recording's address, and
  the page's `ChantPlayer` hook hands it to the site's one chant player,
  marking the row or card that sounds with `data-sounding`; the chant
  sings on, with the mini player (`ChantMiniPlayer`), when the reader
  leaves the page.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Chants.Occasions

  import LumenViaeWeb.Live.Prayers.Painting

  attr :chant, :map, required: true
  attr :class, :string, default: nil

  @doc "The round play control, which plays the chant where it stands."
  def play_disc(assigns) do
    assigns =
      assign(assigns, :label, "#{assigns.chant.latin_title}, #{assigns.chant.english_title}")

    ~H"""
    <button
      type="button"
      class={["chant-disc", @class]}
      data-play={@chant.id}
      data-src={@chant.audio.url}
      data-facts={Library.player_facts_json(@chant)}
      data-label={@label}
      aria-label={"Play #{@label}"}
      aria-pressed="false"
    >
      <span class="hero-play-solid size-3 chant-disc__play" aria-hidden="true" />
      <span class="hero-pause-solid size-3 chant-disc__pause" aria-hidden="true" />
    </button>
    """
  end

  @doc "Three small bars beside whatever is sounding, as a music app marks the song playing."
  def sounding_bars(assigns) do
    ~H"""
    <span class="chant-bars" aria-hidden="true"><span></span><span></span><span></span></span>
    """
  end

  attr :chant, :map, required: true
  attr :shows_setting, :boolean, default: true

  defp names(assigns) do
    ~H"""
    <span class="chant-row__names">
      <span class="chant-row__latin" lang="la">{@chant.latin_title}</span>
      <span class="chant-row__english">{Library.subtitle(@chant, @shows_setting)}</span>
    </span>
    <span class="chant-row__length">{Library.duration_label(@chant.duration)}</span>
    <.sounding_bars />
    """
  end

  attr :chant, :map, required: true
  attr :shows_setting, :boolean, default: true
  attr :disc, :boolean, default: true, doc: "false where a row only opens its chant"

  @doc "A chant with a painting of its own: the painting with its disc, then its names and length."
  def painted_row(assigns) do
    ~H"""
    <div class="chant-row" data-chant-row={@chant.id} data-role="chant-row">
      <span class="chant-row__painting">
        <span class="chant-row__thumb" aria-hidden="true">
          <.painting painting={Library.painting(@chant)} sizes="46px" />
        </span>
        <.play_disc :if={@disc} chant={@chant} class="chant-disc--over" />
      </span>
      <.link navigate={Library.chant_path(@chant.id)} class="chant-row__face">
        <.names chant={@chant} shows_setting={@shows_setting} />
      </.link>
    </div>
    """
  end

  attr :number, :integer, required: true
  attr :chant, :map, required: true
  attr :shows_setting, :boolean, default: true

  @doc "A chant on a shelf whose chants share its painting: its number, names, length and disc."
  def numbered_row(assigns) do
    ~H"""
    <div class="chant-row" data-chant-row={@chant.id} data-role="chant-row">
      <.link navigate={Library.chant_path(@chant.id)} class="chant-row__face">
        <span class="chant-row__number" aria-hidden="true">{@number}</span>
        <.names chant={@chant} shows_setting={@shows_setting} />
      </.link>
      <.play_disc chant={@chant} />
    </div>
    """
  end

  attr :chant, :map, required: true

  @doc "A chant as a square of its painting, its length and its disc on the painting's foot, its names beneath."
  def square_card(assigns) do
    ~H"""
    <div class="chant-card" data-chant-row={@chant.id} data-role="song-card">
      <span class="chant-card__painting">
        <.link
          navigate={Library.chant_path(@chant.id)}
          class="chant-card__picture"
          tabindex="-1"
          aria-hidden="true"
        >
          <.painting painting={Library.painting(@chant)} sizes="(min-width: 640px) 160px, 142px" />
        </.link>
        <span class="chant-card__length" aria-hidden="true">
          {Library.duration_label(@chant.duration)}
        </span>
        <.play_disc chant={@chant} class="chant-disc--card" />
      </span>
      <.link navigate={Library.chant_path(@chant.id)} class="chant-card__names">
        <span class="chant-card__latin" lang="la">{@chant.latin_title}</span>
        <span class="chant-card__english">{Library.subtitle(@chant)}</span>
      </.link>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :note, :string, required: true
  attr :painting, :any, required: true

  @doc "A section as a painted card: its painting, its name and how many chants it holds."
  def section_card(assigns) do
    ~H"""
    <.link navigate={Library.section_path(@id)} class="book-card" data-role="section-card">
      <span class="book-card__painting" aria-hidden="true">
        <.painting
          painting={@painting}
          sizes="(min-width: 1024px) 200px, (min-width: 640px) 30vw, 45vw"
        />
      </span>
      <span class="chant-section-card__title">{@title}</span>
      <span class="book-card__note">{@note}</span>
    </.link>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :painting, :any, required: true
  attr :href, :string, required: true
  attr :role, :string, default: "tile"

  @doc "A quick way in on the Chant page: a square of painting and a name (ChantLibraryView.tile)."
  def tile(assigns) do
    ~H"""
    <.link navigate={@href} class="chant-tile" data-role={@role} data-set-tile={@id}>
      <span class="chant-tile__painting" aria-hidden="true">
        <.painting painting={@painting} sizes="56px" />
      </span>
      <span class="chant-tile__title">{@title}</span>
      <.sounding_bars />
    </.link>
    """
  end

  attr :set, :map, required: true, doc: "a sung set unrolled for the day (Occasions.unroll/3)"

  @doc """
  A sung set as a card (ChantSetCard): its painting, its name, how many
  chants and how long, its disc, which plays the whole set, and its first
  chants listed in order with their lengths. The name opens the set; a
  chant listed opens that chant.
  """
  def set_card(assigns) do
    assigns =
      assigns
      |> assign(:listed, Enum.take(assigns.set.chants, Occasions.listed()))
      |> assign(:more, length(assigns.set.chants) - Occasions.listed())

    ~H"""
    <div
      class="chant-set-card"
      data-set={@set.id}
      data-entries={Occasions.entries_json(@set)}
      data-chants={Occasions.chants_json(@set)}
      data-title={@set.title}
      data-role="set-card"
    >
      <div class="chant-set-card__head">
        <.link navigate={Occasions.set_path(@set.id)} class="chant-set-card__open">
          <span class="chant-set-card__thumb" aria-hidden="true">
            <.painting painting={@set.painting} sizes="76px" />
          </span>
          <span class="chant-set-card__names">
            <span class="chant-set-card__title">{@set.title}</span>
            <span class="chant-set-card__summary">{Occasions.summary(@set)}</span>
          </span>
        </.link>
        <button
          type="button"
          class="chant-disc"
          data-play-set
          data-label={@set.title}
          aria-label={"Play #{@set.title}"}
          aria-pressed="false"
        >
          <span class="hero-play-solid size-3 chant-disc__play" aria-hidden="true" />
          <span class="hero-pause-solid size-3 chant-disc__pause" aria-hidden="true" />
        </button>
      </div>
      <ol class="chant-set-card__list">
        <li :for={{chant, n} <- Enum.with_index(@listed, 1)}>
          <.link navigate={Library.chant_path(chant.id)} class="chant-set-card__chant">
            <span class="chant-set-card__number" aria-hidden="true">{n}</span>
            <span class="chant-set-card__latin" lang="la">{chant.latin_title}</span>
            <span class="chant-set-card__length">{Library.duration_label(chant.duration)}</span>
          </.link>
        </li>
      </ol>
      <p :if={@more > 0} class="chant-set-card__more">and {@more} more</p>
    </div>
    """
  end

  attr :set, :map, required: true, doc: "a sung set unrolled for the day (Occasions.unroll/3)"

  @doc "A sung set as a wide card (ChantSetsPage): its painting, its name, what it is for, how many and how long."
  def wide_set_card(assigns) do
    ~H"""
    <.link navigate={Occasions.set_path(@set.id)} class="chant-wide-set" data-role="wide-set-card">
      <span class="chant-wide-set__painting" aria-hidden="true">
        <.painting painting={@set.painting} sizes="112px" />
      </span>
      <span class="chant-wide-set__words">
        <span class="chant-wide-set__title">{@set.title}</span>
        <span class="chant-wide-set__note">{@set.note}</span>
        <span class="chant-wide-set__summary">{Occasions.summary(@set)}</span>
      </span>
    </.link>
    """
  end

  attr :compact, :boolean, default: false

  @doc """
  Who sang it, on what terms (ChantCredit). The licence asks no
  attribution; the site gives it, and says the adapted files are shared on
  the same terms, which the licence does ask. Compact, the library's one
  line, a link to the singers' site.
  """
  def credit(%{compact: true} = assigns) do
    ~H"""
    <p class="chant-credit">
      <a href={Library.source_site()} class="chant-credit__line" rel="noopener" target="_blank">
        {Library.library_credit()}<span class="text-gilt" aria-hidden="true"> ↗</span>
      </a>
    </p>
    """
  end

  def credit(assigns) do
    ~H"""
    <div class="chant-credit" data-role="credit">
      <p class="chant-credit__line">{Library.credit()}</p>
      <p class="chant-credit__note">{Library.licence_note()}</p>
      <p class="chant-credit__links">
        <a href={Library.source_site()} rel="noopener" target="_blank">verbumgloriae.es</a>
        <a href={Library.licence_url()} rel="noopener" target="_blank">Read the licence</a>
      </p>
    </div>
    """
  end
end
