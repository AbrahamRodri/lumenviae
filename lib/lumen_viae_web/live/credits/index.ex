defmodule LumenViaeWeb.Live.Credits.Index do
  @moduledoc """
  `/credits`, Sources & Credits: where every prayer, painting, chant and
  book on the site comes from. The Prayer Book's chapters fold open (the
  first open), each prayer linked to its page with its origin beneath;
  then the novenas' paintings and the mysteries' woodcuts with their
  credits and licences; the Chant Library's singers and every chant's
  source; the books with their editions and recordings; and the licences
  of the software and fonts that ask for their notice to be shown. A section
  with nothing to credit is left out, and so is its jump pill.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Credits.Sources
  alias LumenViaeWeb.Live.Prayers.Book
  alias LumenViaeWeb.PageMeta

  @contact "rodriguez.abrahamdev@gmail.com"
  @last_checked ~D[2026-11-15]

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_admin
    book = Book.load(actor, novenas: true)
    chapters = Sources.prayer_chapters(book)
    paintings = Sources.novena_paintings(book)
    woodcuts = Sources.woodcuts()
    site_paintings = Sources.site_paintings()
    chant = Sources.chant(actor)
    books = Sources.books(actor)

    sections =
      [
        {chapters != [], "prayers", "Prayers"},
        {paintings != [] or woodcuts != [] or site_paintings != [], "paintings", "Paintings"},
        {chant != nil, "chant", "Chant"},
        {true, "books", "Books"},
        {true, "licences", "Licences"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map(fn {_shown, id, label} -> {id, label} end)

    {:ok,
     socket
     |> PageMeta.put("/credits",
       title: "Sources & Credits",
       description:
         "Where every prayer, painting, chant and book on Lumen Viae comes from, with the real author named wherever it is known.",
       trail: [{"Sources & Credits", "/credits"}]
     )
     |> assign(:contact, @contact)
     |> assign(:last_checked, @last_checked)
     |> assign(:sections, sections)
     |> assign(:chapters, chapters)
     |> assign(:paintings, paintings)
     |> assign(:woodcuts, woodcuts)
     |> assign(:site_paintings, site_paintings)
     |> assign(:chant, chant)
     |> assign(:books, books)
     |> assign(:licences, Sources.licences())
     |> assign(:true_devotion, Sources.true_devotion(actor))}
  end

  attr :id, :string, required: true
  slot :inner_block, required: true

  # A section's heading: the kicker with a hairline running to the edge.
  defp section_heading(assigns) do
    ~H"""
    <h2 id={"#{@id}-heading"} class="flex items-center gap-4 mb-2">
      <span class="kicker min-w-0">{render_slot(@inner_block)}</span>
      <span class="h-px flex-1 bg-night-border" aria-hidden="true"></span>
    </h2>
    """
  end

  attr :licence, :map, default: nil

  # The licence as a small outlined pill, linked to its deed where it has one.
  defp licence_pill(assigns) do
    ~H"""
    <%= if @licence do %>
      <a
        :if={@licence.url}
        href={@licence.url}
        rel="noopener license"
        target="_blank"
        class="credits-licence"
        data-role="licence"
      >
        {@licence.label}
      </a>
      <span :if={!@licence.url} class="credits-licence" data-role="licence">
        {@licence.label}
      </span>
    <% end %>
    """
  end

  attr :src, :string, required: true
  attr :srcset, :string, default: nil

  # The painting's arch, 56 by 72, as the Prayer Book's rows hang theirs.
  defp thumb(assigns) do
    ~H"""
    <.arch_frame
      src={@src}
      srcset={@srcset}
      sizes="56px"
      alt=""
      class="w-14 shrink-0 self-start"
      loading="lazy"
    />
    """
  end
end
