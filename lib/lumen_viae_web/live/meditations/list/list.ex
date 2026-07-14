defmodule LumenViaeWeb.Live.Meditations.List do
  use LumenViaeWeb, :live_view
  import LumenViaeWeb.Live.Meditations.List.FiltersPanel
  import LumenViaeWeb.Live.Meditations.List.Row
  alias LumenViae.Constants
  alias LumenViae.Meditations.Filtering
  alias LumenViae.Rosary

  @sort_options ~w(mystery newest oldest updated author title)
  @default_sort "mystery"

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Meditations")
     |> assign(:expanded_meditation_id, nil)
     |> assign(:selected_ids, MapSet.new())
     |> assign(:mystery_categories, Constants.mystery_category_options())
     |> load_data()}
  end

  # Filters live in the URL so dashboard health links and reloads land on the
  # same filtered view (see ARCHITECTURE.md "URL as Source of Truth").
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:filters, parse_filters(params))
     |> assign(:selected_ids, MapSet.new())
     |> apply_filters()}
  end

  def handle_event("update_filters", params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/meditations?#{filter_query_params(params)}")}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/meditations")}
  end

  def handle_event("toggle_meditation", %{"id" => id}, socket) do
    meditation_id = String.to_integer(id)

    expanded_id =
      if socket.assigns.expanded_meditation_id == meditation_id, do: nil, else: meditation_id

    {:noreply, assign(socket, :expanded_meditation_id, expanded_id)}
  end

  def handle_event("toggle_selected", %{"id" => id}, socket) do
    meditation_id = String.to_integer(id)
    selected = socket.assigns.selected_ids

    selected =
      if MapSet.member?(selected, meditation_id) do
        MapSet.delete(selected, meditation_id)
      else
        MapSet.put(selected, meditation_id)
      end

    {:noreply, assign(socket, :selected_ids, selected)}
  end

  def handle_event("select_all_shown", _params, socket) do
    ids = MapSet.new(socket.assigns.filtered_meditations, & &1.id)
    {:noreply, assign(socket, :selected_ids, ids)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_ids, MapSet.new())}
  end

  def handle_event("bulk_archive", _params, socket) do
    bulk_set_archived(socket, :archive)
  end

  def handle_event("bulk_unarchive", _params, socket) do
    bulk_set_archived(socket, :unarchive)
  end

  def handle_event("bulk_delete", _params, socket) do
    selected = socket.assigns.selected_ids

    count =
      socket.assigns.meditations
      |> Enum.filter(&MapSet.member?(selected, &1.id))
      |> Enum.count(fn meditation ->
        match?({:ok, _}, Rosary.delete_meditation(meditation))
      end)

    {:noreply,
     socket
     |> put_flash(:info, "#{count} #{pluralize_meditation(count)} permanently deleted.")
     |> assign(:selected_ids, MapSet.new())
     |> assign(:expanded_meditation_id, nil)
     |> reload()}
  end

  def handle_event("archive_meditation", %{"id" => id}, socket) do
    set_archived(
      socket,
      id,
      &Rosary.archive_meditation/1,
      "Meditation archived. It is hidden from the public site, along with any set containing it."
    )
  end

  def handle_event("unarchive_meditation", %{"id" => id}, socket) do
    set_archived(
      socket,
      id,
      &Rosary.unarchive_meditation/1,
      "Meditation restored and visible to the public again."
    )
  end

  def handle_event("delete_meditation", %{"id" => id}, socket) do
    meditation = Rosary.get_meditation!(String.to_integer(id))

    case Rosary.delete_meditation(meditation) do
      {:ok, _meditation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meditation deleted successfully")
         |> assign(:expanded_meditation_id, nil)
         |> reload()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete meditation")}
    end
  end

  defp load_data(socket) do
    meditations = Rosary.list_meditations_with_sets()

    socket
    |> assign(:meditations, meditations)
    |> assign(:available_authors, Filtering.available_authors(meditations))
    |> assign(:mysteries, Rosary.list_mysteries())
    |> assign(:meditation_sets, Rosary.list_meditation_sets())
    |> assign(:summary, summarize(meditations))
  end

  defp summarize(meditations) do
    %{
      total: length(meditations),
      archived: Enum.count(meditations, & &1.archived_at),
      missing_audio:
        Enum.count(meditations, &(is_nil(&1.archived_at) and &1.audio_url in [nil, ""])),
      unassigned: Enum.count(meditations, &(&1.meditation_sets == []))
    }
  end

  defp reload(socket) do
    socket = load_data(socket)
    existing_ids = MapSet.new(socket.assigns.meditations, & &1.id)

    socket
    |> update(:selected_ids, &MapSet.intersection(&1, existing_ids))
    |> apply_filters()
  end

  defp apply_filters(socket) do
    filters = socket.assigns.filters

    filtered =
      socket.assigns.meditations
      |> Filtering.filter_meditations(%{
        query: filters.query,
        category: filters.category,
        mystery_id: filters.mystery,
        author: filters.author,
        audio: filters.audio,
        status: filters.status,
        set_id: filters.set
      })
      |> Filtering.sort_meditations(filters.sort)

    assign(socket, :filtered_meditations, filtered)
  end

  defp parse_filters(params) do
    %{
      query: String.trim(params["q"] || ""),
      category: Filtering.blank_to_nil(params["category"]),
      mystery: parse_int(params["mystery"]),
      author: Filtering.blank_to_nil(params["author"]),
      audio: allowed(params["audio"], ~w(with without)),
      status: allowed(params["status"], ~w(active archived)),
      set: parse_set(params["set"]),
      sort: allowed(params["sort"], @sort_options) || @default_sort
    }
  end

  defp filter_query_params(params) do
    [
      q: String.trim(params["q"] || ""),
      category: params["category"],
      mystery: params["mystery"],
      author: params["author"],
      audio: params["audio"],
      status: params["status"],
      set: params["set"],
      sort: params["sort"]
    ]
    |> Enum.reject(fn {key, value} ->
      value in [nil, ""] or (key == :sort and value == @default_sort)
    end)
  end

  defp parse_int(nil), do: nil

  defp parse_int(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_set("none"), do: :none
  defp parse_set(value), do: parse_int(value)

  defp set_archived(socket, id, archive_fun, success_message) do
    meditation = Rosary.get_meditation!(String.to_integer(id))

    case archive_fun.(meditation) do
      {:ok, _meditation} ->
        {:noreply,
         socket
         |> put_flash(:info, success_message)
         |> reload()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update meditation")}
    end
  end

  defp bulk_set_archived(socket, mode) do
    selected = socket.assigns.selected_ids

    {fun, wanted?} =
      case mode do
        :archive -> {&Rosary.archive_meditation/1, &is_nil(&1.archived_at)}
        :unarchive -> {&Rosary.unarchive_meditation/1, &(not is_nil(&1.archived_at))}
      end

    count =
      socket.assigns.meditations
      |> Enum.filter(&MapSet.member?(selected, &1.id))
      |> Enum.filter(wanted?)
      |> Enum.count(fn meditation ->
        match?({:ok, _}, fun.(meditation))
      end)

    verb = if mode == :archive, do: "archived", else: "restored"

    {:noreply,
     socket
     |> put_flash(:info, "#{count} #{pluralize_meditation(count)} #{verb}.")
     |> assign(:selected_ids, MapSet.new())
     |> reload()}
  end

  defp pluralize_meditation(1), do: "meditation"
  defp pluralize_meditation(_), do: "meditations"

  defp allowed(value, options) do
    if value in options, do: value
  end
end
