defmodule LumenViaeWeb.Live.Pray.Index do
  use LumenViaeWeb, :live_view

  alias LumenViae.RateLimit
  alias LumenViae.Rosary
  alias LumenViae.Rosary.{PrayerAudio, Voices}
  alias LumenViae.Storage.S3
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
      [_ | _] ->
        {:ok,
         socket
         |> assign(:set, set)
         |> assign(:voices, Voices.list())
         |> assign(:voice, nil)
         |> assign(:pray_aloud, false)
         |> assign(:spoken_script, nil)
         |> assign(:spoken_index, nil)
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
    |> push_patch(to: build_url(socket.assigns, new_index, socket.assigns.mobile_mode_enabled))
    |> then(&{:noreply, &1})
  end

  def handle_event("previous", _params, socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.set.meditations)
    new_index = (current - 1) |> clamp_index(total)

    socket
    |> push_patch(to: build_url(socket.assigns, new_index, socket.assigns.mobile_mode_enabled))
    |> then(&{:noreply, &1})
  end

  def handle_event("audio_ended", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_pray_aloud", _params, socket) do
    assigns = %{socket.assigns | pray_aloud: !socket.assigns.pray_aloud}

    {:noreply,
     push_patch(socket,
       to: build_url(assigns, socket.assigns.current_index, socket.assigns.mobile_mode_enabled)
     )}
  end

  def handle_event("set_voice", %{"voice" => slug}, socket) do
    voice =
      case Voices.fetch(slug) do
        {:ok, voice} -> voice
        {:error, :unknown_voice} -> socket.assigns.voice
      end

    assigns = %{socket.assigns | voice: voice}

    {:noreply,
     push_patch(socket,
       to: build_url(assigns, socket.assigns.current_index, socket.assigns.mobile_mode_enabled)
     )}
  end

  # The spoken Rosary has reached another decade: follow it to that
  # mystery. Recording `spoken_index` first is what stops handle_params
  # from reading the patch as the reader jumping ahead and seeking the
  # player back to where it already is.
  def handle_event("spoken_at", %{"decade" => decade}, socket) when is_integer(decade) do
    index = clamp_index(decade, socket.assigns.total_count)

    if index == socket.assigns.current_index do
      {:noreply, assign(socket, :spoken_index, index)}
    else
      {:noreply,
       socket
       |> assign(:spoken_index, index)
       |> push_patch(to: build_url(socket.assigns, index, socket.assigns.mobile_mode_enabled))}
    end
  end

  def handle_event("spoken_at", _params, socket), do: {:noreply, socket}

  def handle_event("go_to", %{"index" => index}, socket) do
    total = length(socket.assigns.set.meditations)

    new_index =
      index
      |> normalize_index()
      |> clamp_index(total)

    socket
    |> push_patch(to: build_url(socket.assigns, new_index, socket.assigns.mobile_mode_enabled))
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
       to: build_url(socket.assigns, socket.assigns.current_index, new_mobile_mode)
     )}
  end

  def handle_event("init_mobile_mode", %{"enabled" => enabled}, socket) do
    {:noreply,
     push_patch(socket,
       to: build_url(socket.assigns, socket.assigns.current_index, enabled)
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
     |> assign_voice(params["voice"])
     |> assign_pray_aloud(params["aloud"] == "true")
     |> assign_current_meditation(mystery_index)
     |> follow_with_spoken_rosary(mystery_index)}
  end

  # The voice both the meditation narration and the spoken Rosary are heard
  # in. Changing it re-signs every URL, so it is only done when it changes.
  defp assign_voice(socket, slug) do
    voice =
      case Voices.fetch(slug || "") do
        {:ok, voice} -> voice
        {:error, :unknown_voice} -> Voices.default()
      end

    if socket.assigns.voice == voice do
      socket
    else
      audio_urls = Enum.map(socket.assigns.set.meditations, &narration_url(&1, voice))

      socket
      |> assign(:voice, voice)
      |> assign(:audio_urls, audio_urls)
      |> assign(:spoken_script, nil)
    end
  end

  # A meditation not yet recorded in the chosen voice is still heard, in
  # whichever voice it does have, rather than going silent.
  defp narration_url(meditation, voice) do
    case Rosary.fetch_meditation_audio(meditation, voice.slug) do
      {:ok, %{url: url}} -> url
      _other -> Rosary.get_meditation_audio_url(meditation)
    end
  end

  defp assign_pray_aloud(socket, false) do
    socket |> assign(:pray_aloud, false) |> assign(:spoken_index, nil)
  end

  defp assign_pray_aloud(socket, true) do
    socket
    |> assign(:pray_aloud, true)
    |> then(fn socket ->
      if socket.assigns.spoken_script,
        do: socket,
        else: assign(socket, :spoken_script, build_script(socket))
    end)
  end

  # The reader moved to another mystery themselves - Next, Previous, a
  # bead, an arrow key - so the voice goes there too. Turning the spoken
  # Rosary on counts as arriving at the current mystery.
  defp follow_with_spoken_rosary(%{assigns: %{pray_aloud: false}} = socket, _index), do: socket

  defp follow_with_spoken_rosary(%{assigns: %{spoken_index: nil}} = socket, index),
    do: assign(socket, :spoken_index, index)

  defp follow_with_spoken_rosary(%{assigns: %{spoken_index: index}} = socket, index), do: socket

  defp follow_with_spoken_rosary(socket, index) do
    socket
    |> assign(:spoken_index, index)
    |> push_event("spoken_seek", %{decade: index})
  end

  # Every step of the whole Rosary with its URL, handed to the SpokenRosary
  # hook as JSON. A step with nothing to play - a meditation with no
  # narration in any voice - is dropped, and the prayers carry on around it.
  defp build_script(socket) do
    %{set: set, voice: voice, audio_urls: audio_urls} = socket.assigns
    ttl = Rosary.audio_url_ttl()
    orders = Enum.map(set.meditations, & &1.mystery.order)

    set.category
    |> PrayerAudio.script(orders)
    |> Enum.map(fn step ->
      url =
        case PrayerAudio.clip_for_step(step) do
          nil ->
            Enum.at(audio_urls, step.decade)

          clip ->
            case S3.generate_presigned_url(PrayerAudio.s3_key(voice, clip), expires_in: ttl) do
              {:ok, url} -> url
              {:error, _reason} -> nil
            end
        end

      %{url: url, caption: step.caption, pause_ms: step.pause_ms, decade: step.decade}
    end)
    |> Enum.reject(&is_nil(&1.url))
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

  # The voice and the spoken Rosary ride in the URL with the mystery, so a
  # reload, a shared link or the back button keeps the way someone chose to
  # pray. The default voice is left out to keep ordinary links short.
  defp build_url(assigns, mystery_index, mobile_mode_enabled) do
    query =
      [mystery: mystery_index, mobile: mobile_mode_enabled]
      |> then(&if(assigns.pray_aloud, do: &1 ++ [aloud: true], else: &1))
      |> then(fn query ->
        if assigns.voice && assigns.voice != Voices.default(),
          do: query ++ [voice: assigns.voice.slug],
          else: query
      end)

    ~p"/meditation-sets/#{assigns.set.id}/pray?#{query}"
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
      prayed_aloud: false,
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
        context = %{context | prayed_aloud: socket.assigns.pray_aloud}
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
