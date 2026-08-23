defmodule LumenViaeWeb.Live.Meditations.Authors.List do
  use LumenViaeWeb, :live_view

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Authors")
     |> load_authors()}
  end

  def handle_event("delete_author", %{"id" => id}, socket) do
    author = Rosary.get_author!(id)

    case Rosary.delete_author(author) do
      {:ok, _author} ->
        {:noreply,
         socket
         |> put_flash(:info, "Author deleted. Their sets keep their own artwork and byline.")
         |> load_authors()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete author")}
    end
  end

  defp load_authors(socket) do
    authors = Rosary.list_authors()
    set_counts = Rosary.meditation_set_counts_by_author()

    socket
    |> assign(:authors, authors)
    |> assign(:set_counts, set_counts)
    |> assign(:summary, %{
      total: length(authors),
      served: Enum.count(authors, &Artwork.publishable?/1),
      unlinked: Enum.count(authors, &(Map.get(set_counts, &1.id, 0) == 0))
    })
  end

  def set_count(counts, author_id), do: Map.get(counts, author_id, 0)

  def portrait_state(author) do
    cond do
      Artwork.publishable?(author) -> :served
      author.image_key -> :incomplete
      true -> :none
    end
  end
end
