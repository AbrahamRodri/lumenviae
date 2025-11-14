defmodule LumenViaeWeb.Live.Pray.Index do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  @impl true
  def mount(%{"set_id" => set_id}, _session, socket) do
    set = Rosary.get_meditation_set_with_ordered_meditations!(set_id)

    if set do
      socket =
        socket
        |> assign(:set, set)
        |> assign(:current_index, 0)
        |> assign(:page_title, set.name)
        |> assign(:stage, :overview)
        |> assign(:hide_nav_footer, true)

      {:ok, assign_current_meditation(socket, 0)}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("start_prayer", _params, socket) do
    {:noreply,
     socket
     |> assign(:stage, :prayer)
     |> prepare_current_segment(auto_play: false)}
  end

  def handle_event("next", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)
    new_index = current + 1 |> clamp_index(total)

    socket = assign_current_meditation(socket, new_index)

    socket =
      if socket.assigns.stage == :prayer do
        prepare_current_segment(socket, auto_play: false)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("previous", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)
    new_index = current - 1 |> clamp_index(total)

    socket = assign_current_meditation(socket, new_index)

    socket =
      if socket.assigns.stage == :prayer do
        prepare_current_segment(socket, auto_play: false)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("restore_progress", %{"index" => index}, socket) do
    total = length(socket.assigns.set.meditations)
    valid_index = index |> normalize_index() |> clamp_index(total)

    socket = assign_current_meditation(socket, valid_index)

    {:noreply,
     case socket.assigns.stage do
       :prayer -> prepare_current_segment(socket, auto_play: false)
       _ -> socket
     end}
  end

  def handle_event("audio_ended", _params, socket) do
    case socket.assigns.upcoming_audio_segments do
      [] -> {:noreply, assign(socket, :auto_play, false)}
      _ -> {:noreply, prepare_current_segment(socket, auto_play: true)}
    end
  end

  defp assign_current_meditation(socket, index) do
    meditation = Enum.at(socket.assigns.set.meditations, index)
    audio_segments = build_audio_segments(meditation)

    socket
    |> assign(:current_index, index)
    |> assign(:total_count, length(socket.assigns.set.meditations))
    |> assign(:meditation, meditation)
    |> assign(:audio_segments, audio_segments)
    |> assign(:current_audio_segment, nil)
    |> assign(:upcoming_audio_segments, audio_segments)
    |> assign(:auto_play, false)
  end

  defp prepare_current_segment(socket, opts) do
    {current, remaining} = next_segment(socket.assigns.upcoming_audio_segments)

    socket
    |> assign(:current_audio_segment, current)
    |> assign(:upcoming_audio_segments, remaining)
    |> assign(:auto_play, Keyword.get(opts, :auto_play, false))
  end

  defp build_audio_segments(meditation) do
    [
      {:announcement, Rosary.get_mystery_announcement_audio_url(meditation.mystery)},
      {:description, Rosary.get_mystery_description_audio_url(meditation.mystery)},
      {:intro, Rosary.get_meditation_intro_audio_url(meditation)},
      {:meditation, Rosary.get_meditation_audio_url(meditation)}
    ]
    |> Enum.map(&segment_with_label(&1, meditation))
    |> Enum.filter(& &1)
  end

  defp segment_with_label({_type, nil}, _meditation), do: nil

  defp segment_with_label({type, url}, meditation) do
    %{type: type, url: url, label: segment_label(type, meditation)}
  end

  defp segment_label(:announcement, meditation) do
    "#{ordinal_label(meditation)} Mystery Announcement"
  end

  defp segment_label(:description, _meditation), do: "Mystery Description"
  defp segment_label(:intro, _meditation), do: "Rosary Introduction"
  defp segment_label(:meditation, _meditation), do: "Meditation"

  defp ordinal_label(meditation) do
    index = meditation.mystery.order

    case index do
      1 -> "First"
      2 -> "Second"
      3 -> "Third"
      4 -> "Fourth"
      5 -> "Fifth"
      _ -> Integer.to_string(index)
    end
  end

  defp next_segment([segment | rest]), do: {segment, rest}
  defp next_segment([]), do: {nil, []}

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
end
