defmodule LumenViaeWeb.Live.Pray.Index do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  @impl true
  def mount(%{"set_id" => set_id}, _session, socket) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

    if set do
      {:ok,
       socket
       |> assign(:set, set)
       |> assign(:current_index, 0)
       |> assign(:page_title, set.name)
       |> assign(:phase, :overview)
       |> assign(:intro_pending?, true)
       |> assign(:player_trigger, nil)
       |> assign(:playlist, [])
       |> assign(:current_segment_label, nil)
       |> assign(:hide_nav_footer?, true)}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("next", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)

    new_index = current + 1 |> clamp_index(total)

    {:noreply,
     socket
     |> assign_current_meditation(new_index)
     |> trigger_player()}
  end

  def handle_event("previous", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)
    new_index = current - 1 |> clamp_index(total)

    {:noreply,
     socket
     |> assign_current_meditation(new_index)
     |> trigger_player()}
  end

  def handle_event("restore_progress", %{"index" => index}, socket) do
    total = length(socket.assigns.set.meditations)
    # Ensure index is valid (within bounds)
    valid_index = index |> normalize_index() |> clamp_index(total)
    {:noreply, assign_current_meditation(socket, valid_index)}
  end

  def handle_event("start_prayer", _params, socket) do
    {:noreply,
     socket
     |> assign(:phase, :active)
     |> assign(:intro_pending?, true)
     |> assign_current_meditation(socket.assigns.current_index)
     |> trigger_player()}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    total_count = length(socket.assigns.set.meditations)

    {:noreply,
     socket
     |> assign(:total_count, total_count)
     |> assign_current_meditation(socket.assigns.current_index)}
  end

  defp assign_current_meditation(socket, index) do
    meditation = Enum.at(socket.assigns.set.meditations, index)
    meditation_audio_url = Rosary.get_meditation_audio_url(meditation)

    include_intro? = include_intro_audio?(socket, index)
    playlist = build_playlist(socket.assigns.set, meditation, meditation_audio_url, include_intro?)

    socket
    |> assign(:current_index, index)
    |> assign(:meditation, meditation)
    |> assign(:playlist, playlist)
    |> assign(:current_segment_label, current_segment_label(playlist))
    |> update_intro_flag(include_intro?)
  end

  defp clamp_index(_index, total) when total <= 0, do: 0

  defp clamp_index(index, total) do
    index
    |> max(0)
    |> min(total - 1)
  end

  defp normalize_index(index) when is_integer(index), do: index

  defp normalize_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {value, _} -> value
      :error -> 0
    end
  end

  defp normalize_index(_), do: 0

  defp trigger_player(socket) do
    assign(socket, :player_trigger, System.unique_integer([:positive]) |> Integer.to_string())
  end

  defp include_intro_audio?(socket, index) do
    socket.assigns.phase == :active && socket.assigns.intro_pending? && index == 0
  end

  defp build_playlist(set, meditation, meditation_audio_url, include_intro?) do
    []
    |> maybe_add_intro(set, include_intro?)
    |> maybe_add_segment(
      Rosary.get_mystery_announcement_audio_url(meditation.mystery),
      "Mystery Announcement",
      "announcement"
    )
    |> maybe_add_segment(
      Rosary.get_mystery_description_audio_url(meditation.mystery),
      "Mystery Description",
      "description"
    )
    |> maybe_add_segment(meditation_audio_url, meditation_track_label(meditation), "meditation")
  end

  defp maybe_add_intro(playlist, set, true) do
    case Rosary.get_meditation_set_intro_audio_url(set) do
      nil -> playlist
      url ->
        playlist ++
          [
            %{
              type: "intro",
              label: "Rosary Introduction",
              url: url
            }
          ]
    end
  end

  defp maybe_add_intro(playlist, _set, _include?), do: playlist

  defp maybe_add_segment(playlist, nil, _label, _type), do: playlist

  defp maybe_add_segment(playlist, url, label, type) do
    playlist ++ [%{type: type, label: label, url: url}]
  end

  defp meditation_track_label(%{title: title}) when is_binary(title) and title != "" do
    "Meditation – #{title}"
  end

  defp meditation_track_label(meditation) do
    "Meditation on #{meditation.mystery.name}"
  end

  defp current_segment_label([first | _]), do: first.label
  defp current_segment_label(_), do: nil

  defp update_intro_flag(socket, true), do: assign(socket, :intro_pending?, false)
  defp update_intro_flag(socket, _), do: socket
end
