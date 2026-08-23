defmodule LumenViaeWeb.Live.Pray.Index do
  use LumenViaeWeb, :live_view

  alias LumenViae.RateLimit
  alias LumenViae.Rosary
  alias LumenViaeWeb.BotDetection
  alias LumenViaeWeb.ClientIP

  # A generous ceiling on Rosaries from one address in an hour. A family
  # sharing a connection, or a parish behind one router, stays well under
  # it; a script does not. Praying twenty Rosaries in an hour is not a
  # thing a person does, and this is the cheapest place to say so.
  #
  # Configurable because the whole test suite connects from 127.0.0.1 and
  # would otherwise share a single budget between unrelated tests.
  @default_completions_per_hour 20

  @impl true
  def mount(%{"set_id" => set_id}, session, socket) do
    set = Rosary.get_visible_meditation_set_with_ordered_meditations!(set_id)

    case set.meditations do
      [_ | _] = meditations ->
        # Pre-generate all audio URLs once on mount instead of on every navigation
        audio_urls = Enum.map(meditations, &Rosary.get_meditation_audio_url/1)

        {:ok,
         socket
         |> assign(:set, set)
         |> assign(:audio_urls, audio_urls)
         |> assign(:current_index, 0)
         |> assign(:completion_tracked, false)
         |> assign(:mobile_mode_enabled, false)
         |> assign(:completion_context, completion_context(socket, session))
         |> assign(:page_title, set.name)}

      [] ->
        {:ok,
         socket
         |> put_flash(:error, "This meditation set has no meditations yet")
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("next", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)

    new_index = (current + 1) |> clamp_index(total)

    socket
    |> push_patch(
      to: build_url(socket.assigns.set.id, new_index, socket.assigns.mobile_mode_enabled)
    )
    |> then(&{:noreply, &1})
  end

  def handle_event("previous", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)
    new_index = (current - 1) |> clamp_index(total)

    socket
    |> push_patch(
      to: build_url(socket.assigns.set.id, new_index, socket.assigns.mobile_mode_enabled)
    )
    |> then(&{:noreply, &1})
  end

  def handle_event("audio_ended", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("go_to", %{"index" => index}, socket) do
    total = length(socket.assigns.set.meditations)

    new_index =
      index
      |> normalize_index()
      |> clamp_index(total)

    socket
    |> push_patch(
      to: build_url(socket.assigns.set.id, new_index, socket.assigns.mobile_mode_enabled)
    )
    |> then(&{:noreply, &1})
  end

  # The one place a completion is recorded. Pressing this is a deliberate
  # act at the end of the last mystery; arriving at the last mystery is not,
  # and counting arrivals meant every crawler that walked the set left a
  # prayed Rosary behind it.
  def handle_event("complete", _params, socket) do
    socket =
      if socket.assigns.completion_tracked do
        socket
      else
        maybe_record_completion(socket)
        assign(socket, :completion_tracked, true)
      end

    {:noreply, push_navigate(socket, to: ~p"/mysteries/#{socket.assigns.set.category}")}
  end

  def handle_event("key_nav", %{"key" => "ArrowRight"}, socket) do
    if socket.assigns.current_index < socket.assigns.total_count - 1 do
      handle_event("next", %{}, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event("key_nav", %{"key" => "ArrowLeft"}, socket) do
    handle_event("previous", %{}, socket)
  end

  def handle_event("key_nav", _params, socket), do: {:noreply, socket}

  def handle_event("toggle_mobile_mode", _params, socket) do
    new_mobile_mode = !socket.assigns.mobile_mode_enabled

    {:noreply,
     push_patch(socket,
       to: build_url(socket.assigns.set.id, socket.assigns.current_index, new_mobile_mode)
     )}
  end

  def handle_event("init_mobile_mode", %{"enabled" => enabled}, socket) do
    {:noreply,
     push_patch(socket,
       to: build_url(socket.assigns.set.id, socket.assigns.current_index, enabled)
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    total_count = length(socket.assigns.set.meditations)

    # Read mystery index from URL params, default to current index or 0
    mystery_index =
      params
      |> Map.get("mystery", "0")
      |> normalize_index()
      |> clamp_index(total_count)

    # Read mobile mode from URL params, default to nil (will be set by hook)
    mobile_mode =
      case Map.get(params, "mobile") do
        "true" -> true
        "false" -> false
        _ -> nil
      end

    socket =
      if mobile_mode != nil do
        assign(socket, :mobile_mode_enabled, mobile_mode)
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:total_count, total_count)
     |> assign_current_meditation(mystery_index)}
  end

  defp assign_current_meditation(socket, index) do
    meditation = Enum.at(socket.assigns.set.meditations, index)
    audio_presigned_url = Enum.at(socket.assigns.audio_urls, index)

    socket
    |> assign(:current_index, index)
    |> assign(:meditation, meditation)
    |> assign(:audio_presigned_url, audio_presigned_url)
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

  defp build_url(set_id, mystery_index, mobile_mode_enabled) do
    ~p"/meditation-sets/#{set_id}/pray?mystery=#{mystery_index}&mobile=#{mobile_mode_enabled}"
  end

  # Roman numerals for mystery indices (sets range from 5 to 7 meditations)
  defp roman(n) when n in 1..20 do
    Enum.at(
      ~w(I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX),
      n - 1
    )
  end

  defp roman(n), do: Integer.to_string(n)

  ## Completion analytics

  # The address comes from the session, put there by Plugs.PutClientIP
  # during the HTTP request. It cannot come from `connect_info`: the only
  # header a socket is given is `X-Forwarded-For`, and reading that without
  # knowing the proxy layout is what previously recorded every Rosary as
  # having been prayed from Fly's proxy.
  #
  # The user agent does reach the socket, and is read here rather than at
  # the moment Complete is pressed because connect info belongs to the
  # connection. `nil` on the disconnected mount is harmless: the button
  # cannot be pressed until the socket has connected and mounted again.
  defp completion_context(socket, session) do
    %{
      source: "web",
      ip: ClientIP.from_session(session),
      bot?: BotDetection.bot?(get_connect_info(socket, :user_agent))
    }
  end

  # Two things can stop a completion being written, and they guard against
  # different problems.
  #
  # The bot check is about the figures: a crawler that runs the LiveView
  # and trips the button leaves a Rosary nobody prayed.
  #
  # The rate limit is about abuse, and is keyed on the full address rather
  # than the truncated prefix that gets stored - the whole job here is
  # telling neighbours apart, which is exactly what truncating destroys.
  # With no address to key on the limit cannot apply, and the completion is
  # allowed; that is the disconnected-mount case and a handful of proxies,
  # not an open door.
  defp maybe_record_completion(socket) do
    context = socket.assigns.completion_context

    cond do
      context.bot? ->
        :ok

      rate_limited?(context.ip) ->
        :ok

      true ->
        Rosary.record_completion(socket.assigns.set.id, context)
        :ok
    end
  end

  defp rate_limited?(nil), do: false

  defp rate_limited?(ip) do
    RateLimit.check("completion:" <> ip, completions_per_hour(), :timer.hours(1)) != :ok
  end

  defp completions_per_hour do
    Application.get_env(:lumen_viae, :completions_per_hour, @default_completions_per_hour)
  end
end
