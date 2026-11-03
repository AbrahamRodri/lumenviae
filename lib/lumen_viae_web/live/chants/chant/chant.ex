defmodule LumenViaeWeb.Live.Chants.Chant do
  @moduledoc """
  `/chant/:chant_id`: one chant on a page of its own, as the app's
  `ChantView` (its Now Playing): the chant's painting at the head,
  dissolving into the page, its Latin name over its English; the
  scrubber, the time and "Line 3 of 12", back a line, the gold play, on a
  line (by ten seconds where a chant has no timed lines), back and on
  greyed until it has played; the quiet capsule of Repeat this line
  (which starts it) and three-quarter speed; the line being sung, Latin
  over English, or when it is sung for a chant with no timed lines. Beside it, from 1024px, the Words (the
  app's Words sheet): every line, the one sounding lit, a click plays from
  it, in Latin, English or Both (`?words=`). Then the prayer it sings in
  the Prayer Book, its other settings and the singers' credit.

  The recording is the app's own, the public file on the site's bucket,
  played through the site's one chant player (the root layout's `<audio>`)
  that the `ChantPlayer` hook drives, so it sings on when the reader
  leaves; the mini player (`ChantMiniPlayer`) stands aside on this page,
  as the app's does on a chant's. The app's score window,
  learning, favourites, sets, Take turns and sleep timer are not here.
  An id the library does not have is a 404.

  The Sheet Music opens the whole score over the page (`?score=full`), as
  the app's `ChantScoreSheet`: the painting with the names and DONE at
  its head, every page of the score in order, each named where there is
  more than one, drawn by the `ChantScore` hook from the apps' own packed
  drawings (served through `/chant/scores/:file`), brought closer by a
  double-click or the zoom buttons, and a small player at its foot that
  drives the page's own recording. Back, DONE or Escape close it.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Prayers.Book
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Chants.Parts
  import LumenViaeWeb.Live.Prayers.Painting

  @words [{"latin", "Latin"}, {"english", "English"}, {"both", "Both"}]

  @impl true
  def mount(%{"chant_id" => id}, _session, socket) do
    actor = socket.assigns.current_admin
    library = Library.load(actor)

    chant =
      Library.chant(library, id) ||
        raise LumenViaeWeb.NotFoundError, message: "unknown chant: #{inspect(id)}"

    book = Book.load(actor)
    group = Library.group(library, chant.group_id)

    {:ok,
     socket
     |> PageMeta.put(Library.chant_path(id),
       title: "#{chant.latin_title} (#{chant.english_title}), Chant",
       description: description(chant),
       image: PageMeta.named_image(Library.painting(chant)),
       trail:
         [{"Chant", "/chant"}] ++
           if(group,
             do: [{Library.card_title(group), Library.section_path(group.id)}],
             else: []
           ) ++
           [{chant.latin_title, Library.chant_path(id)}]
     )
     |> assign(:chant, chant)
     |> assign(:group, group)
     |> assign(:painting, Library.hero(Library.painting(chant)))
     |> assign(:prayers, Book.prayers(book, chant.prayer_ids))
     |> assign(:others, Library.other_settings(library, chant))
     |> assign(:words_choices, @words)
     |> assign(:words, "both")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:words, words(params["words"]))
     |> assign(:score, params["score"] == "full" and socket.assigns.chant.score != [])}
  end

  @doc "The words chosen in the link: Latin, English, or Both (the default, never written)."
  def words(value) when value in ["latin", "english"], do: value
  def words(_value), do: "both"

  defp words_path(id, "both"), do: Library.chant_path(id)
  defp words_path(id, words), do: Library.chant_path(id) <> "?" <> URI.encode_query(words: words)

  # The full score over the page, the Words kept in the link.
  defp score_path(id, "both"), do: Library.chant_path(id) <> "?score=full"

  defp score_path(id, words),
    do: Library.chant_path(id) <> "?" <> URI.encode_query(words: words, score: "full")

  defp description(chant) do
    first = chant.lines |> Enum.take(2) |> Enum.map_join(" ", & &1.english)

    "#{chant.latin_title}, #{Library.subtitle(chant)}, sung in Gregorian chant (#{Library.duration_label(chant.duration)}). #{chant.detail}. #{first}"
  end
end
