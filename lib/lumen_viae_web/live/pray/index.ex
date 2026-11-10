defmodule LumenViaeWeb.Live.Pray.Index do
  @moduledoc """
  The prayer page: the whole Rosary, from the Sign of the Cross to the
  last Amen, as the iOS app prays it.

  Two routes reach it. `/meditation-sets/:set_id/pray` prays a set, with
  its meditations or as the Scriptural Rosary; `/mysteries/:category/pray`
  prays a category without a set, as the Scriptural Rosary or with no
  meditation. Either way it is the app's simple Rosary: one player that
  says every prayer aloud, a prayer at a time on the screen, with the words
  lit as they are read where the recording is timed.
  `LumenViaeWeb.Live.Pray.Params` is the URL, `LumenViaeWeb.Live.Pray.Sequence`
  the order of prayers.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Rosary
  alias LumenViae.Rosary.{Categories, PrayerAudio, Voices}
  alias LumenViae.Storage.S3
  alias LumenViaeWeb.BotDetection
  alias LumenViaeWeb.ClientIP
  alias LumenViaeWeb.PageMeta

  alias LumenViaeWeb.Live.Pray.{
    BeadScreen,
    Completion,
    Controls,
    Painting,
    Params,
    Sequence,
    Strand
  }

  @advance_keys ["ArrowRight", "ArrowDown", " ", "Spacebar", "Enter"]
  @back_keys ["ArrowLeft", "ArrowUp"]

  @impl true
  def mount(%{"set_id" => set_id}, session, socket) do
    # Raises the 404 for a set that does not exist or is hidden, and a set
    # with no meditations is hidden, so what comes back always has something
    # to pray.
    set =
      case Rosary.fetch_visible_meditation_set(set_id, actor: socket.assigns.current_admin) do
        {:ok, set} -> set
        {:error, :not_found} -> raise LumenViaeWeb.NotFoundError, message: "no such set"
      end

    socket
    |> assign(:route, :set)
    |> assign(:set, set)
    |> assign(:category, set.category)
    |> assign(:base_path, ~p"/meditation-sets/#{set.id}/pray")
    |> assign(:storage_key, "set:#{set.id}")
    |> assign(:decades, Sequence.set_decades(set))
    |> assign(:heading, set.name)
    |> put_set_meta(set)
    |> mount_common(session)
  end

  def mount(%{"category" => category}, session, socket) do
    if category not in Categories.slugs() do
      raise LumenViaeWeb.NotFoundError, message: "unknown mystery category: #{category}"
    end

    mysteries = Rosary.list_mysteries_by_category!(category, actor: socket.assigns.current_admin)

    socket
    |> assign(:route, :category)
    |> assign(:set, nil)
    |> assign(:category, category)
    |> assign(:base_path, ~p"/mysteries/#{category}/pray")
    |> assign(:storage_key, "mysteries:#{category}")
    |> assign(:decades, Sequence.category_decades(category, mysteries))
    |> assign(:heading, Categories.devotion_title(category))
    |> put_category_meta(category)
    |> mount_common(session)
  end

  # What search results and link previews say about the page, from the
  # decades it prays: the set's name and author and the mysteries, with the
  # first mystery's painting.
  defp put_set_meta(socket, set) do
    %{decades: decades} = socket.assigns

    PageMeta.put(
      socket,
      ~p"/meditation-sets/#{set.id}/pray",
      PageMeta.pray_set(set, Enum.map(decades, & &1.name), hd(decades).key)
    )
  end

  defp put_category_meta(socket, category) do
    PageMeta.put(
      socket,
      ~p"/mysteries/#{category}/pray",
      PageMeta.pray_category(category, Enum.map(socket.assigns.decades, & &1.name))
    )
  end

  defp mount_common(socket, session) do
    {:ok,
     socket
     |> assign(:voices, Voices.list())
     |> assign(:voice, nil)
     |> assign(:narrations, [])
     |> assign(:form, nil)
     |> assign(:extras, [])
     |> assign(:language, Sequence.default_language())
     |> assign(:sequence, nil)
     |> assign(:page, 0)
     |> assign(:step, 0)
     |> assign(:spoken_script, nil)
     |> assign(:spoken_at, nil)
     |> assign(:seek, 0)
     |> assign(:fresh, false)
     |> assign(:resume, nil)
     |> assign(:panel_open, false)
     |> assign(:go_to_open, false)
     |> assign(:show_meditation, false)
     |> assign(:completed, false)
     |> assign(:completion_tracked, false)
     |> assign(:completion_context, completion_context(socket, session))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    first_visit? = is_nil(socket.assigns.sequence)
    form = Params.form(params, socket.assigns.route)
    player_before = player(socket)

    socket =
      socket
      |> assign_voice(params["voice"])
      |> assign_form(form)

    page = Params.page(params, length(socket.assigns.decades))
    step = min(Params.step(params), Sequence.step_count(socket.assigns.sequence, page) - 1)

    moved? = {page, step} != {socket.assigns.page, socket.assigns.step}
    # The voice reaching the next prayer records spoken_at before it turns
    # the page; only a move of the reader's own puts the resume offer away.
    voice_moved? = socket.assigns.spoken_at == {page, step}

    {:noreply,
     socket
     |> assign(
       :fresh,
       if(first_visit?, do: is_nil(params["mystery"]), else: socket.assigns.fresh)
     )
     |> then(
       &if((moved? or not first_visit?) and not voice_moved?,
         do: assign(&1, :resume, nil),
         else: &1
       )
     )
     |> then(&if(moved?, do: assign(&1, :show_meditation, false), else: &1))
     |> assign(:page, page)
     |> assign(:step, max(step, 0))
     |> assign_script()
     |> follow_with_spoken_rosary()
     |> then(&if(first_visit?, do: &1, else: play_new_player(&1, player_before)))}
  end

  # The player starts on its own when it arrives (the SpokenRosary hook
  # tries at once): the tap on Pray that opened the page lets a browser
  # play. A page opened cold, from a link or a reload, has had no tap, and
  # the browser keeps it waiting for Play. A player remounted because the
  # reader chose another voice, form or closing prayers is told to play as
  # well, since that choice was a tap.
  #
  # A player is known by its id, which changes whenever it is remounted.
  defp player(socket), do: socket.assigns.sequence && spoken_id(socket.assigns)

  defp play_new_player(socket, before) do
    if player(socket) != before,
      do: push_event(socket, "spoken_play", %{}),
      else: socket
  end

  ## Moving through the Rosary

  @impl true
  def handle_event("next", _params, socket), do: {:noreply, move(socket, :next)}
  def handle_event("previous", _params, socket), do: {:noreply, move(socket, :previous)}
  def handle_event("advance", _params, socket), do: {:noreply, move(socket, :next)}

  def handle_event("go_to", %{"page" => page}, socket) do
    case integer(page) do
      nil ->
        {:noreply, socket}

      page ->
        page = page |> max(0) |> min(Sequence.last_page(socket.assigns.sequence))
        {:noreply, socket |> assign(:go_to_open, false) |> patch_to(page, 0)}
    end
  end

  def handle_event("go_to", _params, socket), do: {:noreply, socket}

  def handle_event("key_nav", %{"key" => key}, socket) do
    direction =
      cond do
        key in @advance_keys -> :next
        key in @back_keys -> :previous
        true -> nil
      end

    if direction && !socket.assigns.completed,
      do: {:noreply, move(socket, direction)},
      else: {:noreply, socket}
  end

  def handle_event("key_nav", _params, socket), do: {:noreply, socket}

  def handle_event("audio_ended", _params, socket), do: {:noreply, socket}

  ## How the Rosary is prayed

  def handle_event("set_voice", %{"voice" => slug}, socket) do
    voice =
      case Voices.resolve(slug) do
        {:ok, voice} -> voice
        {:error, :unknown_voice} -> socket.assigns.voice
      end

    assigns = %{socket.assigns | voice: voice}
    {:noreply, push_patch(socket, to: pray_url(assigns, assigns.page, assigns.step))}
  end

  def handle_event("set_form", %{"form" => form}, socket) do
    if form in Params.forms(socket.assigns.route) do
      assigns = %{socket.assigns | form: form}
      {:noreply, push_patch(socket, to: pray_url(assigns, assigns.page, 0))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_extra", %{"extra" => extra}, socket) do
    if extra in Sequence.extra_ids() do
      extras =
        if extra in socket.assigns.extras,
          do: List.delete(socket.assigns.extras, extra),
          else: [extra | socket.assigns.extras]

      before = player(socket)
      socket = socket |> set_extras(extras) |> play_new_player(before)
      {:noreply, push_event(socket, "prayer:extras", %{extras: socket.assigns.extras})}
    else
      {:noreply, socket}
    end
  end

  # The PrayerMemory hook hands back the closing prayers this browser
  # chose last time.
  def handle_event("restore_extras", %{"extras" => extras}, socket) when is_list(extras) do
    {:noreply, set_extras(socket, Enum.filter(extras, &(&1 in Sequence.extra_ids())))}
  end

  def handle_event("restore_extras", _params, socket), do: {:noreply, socket}

  # The language of the prayers is this browser's, like the closing
  # prayers: chosen here and kept by the PrayerMemory hook, never in the
  # URL. Only the prayers change; the spoken Rosary is English, so a
  # prayer in Latin is not lit as it is read.
  def handle_event("set_language", %{"language" => language}, socket) do
    if language in Sequence.languages() do
      {:noreply,
       socket
       |> assign(:language, language)
       |> push_event("prayer:language", %{language: language})}
    else
      {:noreply, socket}
    end
  end

  # The PrayerMemory hook hands back the language this browser chose.
  def handle_event("restore_language", %{"language" => language}, socket) do
    if language in Sequence.languages(),
      do: {:noreply, assign(socket, :language, language)},
      else: {:noreply, socket}
  end

  def handle_event("restore_language", _params, socket), do: {:noreply, socket}

  # A click carries its phx-value; anything else sent under these names is
  # not one, and changes nothing.
  def handle_event(event, _params, socket)
      when event in ~w(set_voice set_form toggle_extra set_language),
      do: {:noreply, socket}

  def handle_event("toggle_panel", _params, socket) do
    {:noreply,
     socket |> assign(:panel_open, !socket.assigns.panel_open) |> assign(:go_to_open, false)}
  end

  def handle_event("toggle_go_to", _params, socket) do
    {:noreply,
     socket |> assign(:go_to_open, !socket.assigns.go_to_open) |> assign(:panel_open, false)}
  end

  def handle_event("close_go_to", _params, socket),
    do: {:noreply, assign(socket, :go_to_open, false)}

  def handle_event("toggle_meditation", _params, socket),
    do: {:noreply, assign(socket, :show_meditation, !socket.assigns.show_meditation)}

  ## Continue where you left off

  # The PrayerMemory hook found a place saved in this browser. It is
  # offered only to a reader who arrived at the beginning and has not
  # moved yet; a link to a particular mystery means that mystery.
  # What it hands back was read from localStorage, so it may be anything:
  # only a string or a number is a place.
  def handle_event("resume_available", %{"mystery" => mystery} = saved, socket)
      when is_binary(mystery) or is_integer(mystery) do
    %{fresh: fresh, page: page, step: step, sequence: sequence} = socket.assigns
    decades = length(socket.assigns.decades)
    saved_page = Params.page(%{"mystery" => to_string(mystery)}, decades)

    saved_step =
      min(max(integer(saved["step"]) || 0, 0), Sequence.step_count(sequence, saved_page) - 1)

    if fresh and {page, step} == {0, 0} and {saved_page, saved_step} != {0, 0} do
      {:noreply,
       assign(socket, :resume, %{
         page: saved_page,
         step: max(saved_step, 0),
         label: describe(socket.assigns, saved_page, max(saved_step, 0))
       })}
    else
      {:noreply, socket}
    end
  end

  def handle_event("resume_available", _params, socket), do: {:noreply, socket}

  def handle_event("resume", _params, socket) do
    case socket.assigns.resume do
      nil ->
        {:noreply, socket}

      resume ->
        {:noreply, push_patch(socket, to: pray_url(socket.assigns, resume.page, resume.step))}
    end
  end

  def handle_event("dismiss_resume", _params, socket),
    do: {:noreply, socket |> assign(:resume, nil) |> assign(:fresh, false)}

  ## The spoken Rosary

  # The voice has moved on: the page follows it to the prayer it is on.
  # Recording `spoken_at` first is what stops handle_params from reading
  # the patch as the reader moving and seeking the voice to where it
  # already is.
  #
  # Each seek the page sends the voice is numbered, and the voice says which
  # it last heard. A report from before the latest seek was sent while the
  # reader was moving, about a place they have already left, and following
  # it would turn the page back under them; the voice reports again once it
  # has caught up.
  def handle_event("spoken_at", %{"screen" => index} = params, socket)
      when is_integer(index) do
    stale? = is_integer(params["seek"]) and params["seek"] < socket.assigns.seek

    if not stale?,
      do: follow_voice(socket, index),
      else: {:noreply, socket}
  end

  def handle_event("spoken_at", _params, socket), do: {:noreply, socket}

  ## Completion

  # The one place a completion is recorded. Pressing this is a deliberate
  # act at the end of the Rosary; arriving at the end is not, and counting
  # arrivals meant every crawler that walked the set left a prayed Rosary
  # behind it. A Rosary prayed without a set records nothing: a completion
  # belongs to a set.
  #
  # Only at the end: the button is not offered before then, so a complete
  # from anywhere else is not a reader finishing the Rosary.
  def handle_event("complete", _params, socket) do
    if at_end?(socket.assigns), do: {:noreply, complete(socket)}, else: {:noreply, socket}
  end

  defp follow_voice(socket, index) do
    case Sequence.screen_at(socket.assigns.sequence, index) do
      nil ->
        {:noreply, socket}

      screen ->
        {page, step} = target = {screen.page, screen.step}
        socket = assign(socket, :spoken_at, target)

        if target == {socket.assigns.page, socket.assigns.step},
          do: {:noreply, socket},
          else:
            {:noreply,
             push_patch(socket, to: pray_url(socket.assigns, page, step), replace: true)}
    end
  end

  ## Helpers

  defp complete(socket) do
    socket =
      if socket.assigns.completion_tracked do
        socket
      else
        maybe_record_completion(socket)
        assign(socket, :completion_tracked, true)
      end

    socket |> assign(:completed, true) |> push_event("prayer:top", %{})
  end

  # A whole number from a client: a string of digits or an integer, or nil.
  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp integer(_value), do: nil

  defp at_end?(assigns), do: is_nil(Sequence.next(assigns.sequence, assigns.page, assigns.step))

  defp current_screen(assigns), do: Sequence.screen(assigns.sequence, assigns.page, assigns.step)

  # The timed lines of what is heard on the screen the reader is on, by
  # the kind of words they belong to (`:prayer`, `:verse`, `:meditation`).
  # A prayer shown in Latin is heard in English, so it is not lit.
  defp current_timings(assigns) do
    screen = current_screen(assigns)

    for step <- assigns.spoken_script || [],
        step.screen == screen.index,
        step.lines,
        step.kind in ~w(prayer verse meditation),
        not (step.kind == "prayer" and assigns.language != "en"),
        into: %{},
        do: {String.to_existing_atom(step.kind), step.lines}
  end

  # Remounted, and so restarted where the reader is, whenever what it
  # would say changes.
  defp spoken_id(assigns),
    do: "spoken-rosary-#{assigns.voice.slug}-#{assigns.form}-#{Enum.join(assigns.extras, "-")}"

  defp move(socket, direction) do
    %{sequence: sequence, page: page, step: step} = socket.assigns

    target =
      case direction do
        :next -> Sequence.next(sequence, page, step)
        :previous -> Sequence.previous(sequence, page, step)
      end

    case target do
      nil -> socket
      {page, step} -> patch_to(socket, page, step)
    end
  end

  defp patch_to(socket, page, step) do
    push_patch(socket,
      to: pray_url(socket.assigns, page, step),
      replace: page == socket.assigns.page
    )
  end

  defp pray_url(assigns, page, step) do
    Params.url(
      assigns.base_path,
      %{
        route: assigns.route,
        form: assigns.form,
        voice: assigns.voice,
        decades: length(assigns.decades)
      },
      page,
      step
    )
  end

  # Where a saved place is, in words: the page, and the bead on it.
  defp describe(assigns, page, step) do
    page_title =
      case Sequence.page(assigns.sequence, page) do
        %{kind: :opening} -> "The opening prayers"
        %{kind: :closing} -> "The closing prayers"
        %{decade: decade} -> decade.label || decade.name
        nil -> nil
      end

    case Sequence.screen(assigns.sequence, page, step) do
      %{caption: caption} when step > 0 -> "#{page_title}, #{caption}"
      _ -> page_title
    end
  end

  # The voice both the meditation narration and the spoken Rosary are heard
  # in. Changing it re-signs every URL, so it is only done when it changes.
  defp assign_voice(socket, slug) do
    voice =
      case Voices.resolve(slug || "") do
        {:ok, voice} -> voice
        {:error, :unknown_voice} -> Voices.default()
      end

    if socket.assigns.voice == voice do
      socket
    else
      # The first, static render (every crawler's) reads no recordings: the
      # player is filled once the page connects.
      narrations =
        if connected?(socket),
          do: Enum.map(socket.assigns.decades, &narration(&1.meditation, voice)),
          else: []

      socket
      |> assign(:voice, voice)
      |> assign(:narrations, narrations)
      |> assign(:spoken_script, nil)
    end
  end

  # A meditation not yet recorded in the chosen voice is still heard, in
  # whichever voice it does have, rather than going silent: its URL and
  # the timed lines of that same recording.
  defp narration(nil, _voice), do: nil

  defp narration(meditation, voice) do
    with :error <- fetch_narration(meditation, voice.slug),
         :error <- fetch_narration(meditation, nil),
         do: nil
  end

  defp fetch_narration(meditation, slug) do
    case Rosary.fetch_meditation_audio(meditation, slug) do
      {:ok, audio} -> audio
      _other -> :error
    end
  end

  defp assign_form(socket, form) do
    if socket.assigns.form == form and socket.assigns.sequence do
      socket
    else
      socket |> assign(:form, form) |> rebuild_sequence()
    end
  end

  defp set_extras(socket, extras) do
    # Said in the app's order whatever order they were chosen in.
    extras = Enum.filter(Sequence.extra_ids(), &(&1 in extras))

    if extras == socket.assigns.extras do
      socket
    else
      %{page: page, step: step} = socket.assigns

      socket
      |> assign(:extras, extras)
      |> rebuild_sequence()
      |> then(fn socket ->
        last = Sequence.last_page(socket.assigns.sequence)
        step = min(step, Sequence.step_count(socket.assigns.sequence, min(page, last)) - 1)
        socket |> assign(:page, min(page, last)) |> assign(:step, max(step, 0))
      end)
      |> assign_script()
      |> assign(:spoken_at, nil)
      |> follow_with_spoken_rosary()
    end
  end

  defp rebuild_sequence(socket) do
    %{category: category, form: form, extras: extras, decades: decades} = socket.assigns

    socket
    |> assign(:sequence, Sequence.build(category, form, extras, decades))
    |> assign(:spoken_script, nil)
  end

  # A new script is a new player, which counts its seeks from 0.
  #
  # The first, static render (the one every crawler gets) signs nothing
  # and sends no script: it holds only the prayers' steps, unsigned, so the
  # page shows the player where it will be and nothing moves when the page
  # connects and the real script arrives. The hook mounts only then.
  defp assign_script(socket) do
    cond do
      socket.assigns.spoken_script ->
        socket

      connected?(socket) ->
        socket |> assign(:spoken_script, build_script(socket)) |> assign(:seek, 0)

      true ->
        assign(socket, :spoken_script, static_script(socket))
    end
  end

  defp static_script(socket) do
    if S3.credentials?() do
      for {step, _screen} <- socket.assigns.sequence.steps,
          PrayerAudio.clip_for_step(step),
          do: %{url: nil, lines: nil, kind: nil, screen: nil, page: nil}
    else
      []
    end
  end

  # The reader moved themselves - Next, Previous, a bead, a key, a swipe -
  # so the voice goes there too. A new player counts as arriving where the
  # reader already is.

  defp follow_with_spoken_rosary(%{assigns: %{spoken_at: nil}} = socket),
    do: assign(socket, :spoken_at, {socket.assigns.page, socket.assigns.step})

  defp follow_with_spoken_rosary(socket) do
    %{page: page, step: step, spoken_at: spoken_at} = socket.assigns

    if spoken_at == {page, step} do
      socket
    else
      screen = Sequence.screen(socket.assigns.sequence, page, step)

      seek = socket.assigns.seek + 1

      socket
      |> assign(:spoken_at, {page, step})
      |> assign(:seek, seek)
      |> push_event("spoken_seek", %{screen: screen && screen.index, seek: seek})
    end
  end

  # Every step of the whole Rosary with its URL, handed to the SpokenRosary
  # hook as JSON, each with the page and the screen it is shown on, its
  # kind (a meditation is always heard at its own speed, the prayers at
  # the reader's) and its timed lines, nil where the recording has none. A
  # step with nothing to play - a meditation with no narration in any
  # voice - is dropped, and the prayers carry on around it.
  defp build_script(socket) do
    %{sequence: sequence, voice: voice, narrations: narrations} = socket.assigns
    ttl = Rosary.audio_url_ttl()

    pages =
      for page <- sequence.pages,
          screen <- page.screens,
          into: %{},
          do: {screen.index, page.index}

    sequence.steps
    |> Enum.map(fn {step, screen} ->
      {url, lines} =
        case PrayerAudio.clip_for_step(step) do
          nil when step.kind == :meditation ->
            case Enum.at(narrations, step.decade) do
              %{url: url} = narration -> {url, narration[:lines]}
              nil -> {nil, nil}
            end

          nil ->
            {nil, nil}

          clip ->
            case S3.generate_presigned_url(PrayerAudio.served_key(voice, clip), expires_in: ttl) do
              {:ok, url} -> {url, PrayerAudio.lines(voice, clip)}
              {:error, _reason} -> {nil, nil}
            end
        end

      %{
        url: url,
        kind: to_string(step.kind),
        lines: timed_lines(lines),
        caption: step.caption,
        pause_ms: step.pause_ms,
        page: pages[screen],
        screen: screen
      }
    end)
    |> Enum.reject(&is_nil(&1.url))
  end

  # The timed lines as the hook reads them; none at all is nil, so a
  # recording without timings is never lit.
  defp timed_lines(nil), do: nil
  defp timed_lines([]), do: nil

  defp timed_lines(lines),
    do: Enum.map(lines, &%{text: &1.text, start: &1.start, end: Map.fetch!(&1, :end)})

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
  # The rate limit is about abuse, and is not here: it is on the action
  # (see `LumenViae.Limits`), keyed on the full address
  # passed in the context rather than the truncated prefix that gets stored,
  # on the budget the REST route and GraphQL spend too. A refused completion
  # comes back as an error that is dropped, as it always was: nothing on the
  # page says a Rosary was not counted. With no address to key on the limit
  # cannot apply, and the completion is allowed; that is the
  # disconnected-mount case and a handful of proxies, not an open door.
  defp maybe_record_completion(%{assigns: %{set: nil}}), do: :ok

  defp maybe_record_completion(socket) do
    context = socket.assigns.completion_context

    if context.bot? do
      :ok
    else
      context = %{context | prayed_aloud: socket.assigns.spoken_script != []}

      Rosary.record_completion(socket.assigns.set.id, context,
        actor: socket.assigns.current_admin
      )

      :ok
    end
  end
end
