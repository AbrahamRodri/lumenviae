defmodule LumenViaeWeb.Live.Admin.RosaryAudio do
  @moduledoc """
  The spoken Rosary, clip by clip, for one voice at a time: whether each
  recording is in the bucket, and a player for listening to it.

  Two jobs. The first is coverage: the app refuses to start a spoken Rosary
  without a Hail Mary and skips any other clip it cannot fetch, so a gap is
  silent in the app and has to be visible somewhere. The second is the
  listening pass - a generation run proves a file exists, not that the
  narrator said "Pontius Pilate" properly - and this is the one screen that
  plays every clip with the words it was meant to say beside it.

  Checking coverage is one HEAD per clip in every voice (the scoped IAM
  user cannot list the bucket), so it runs after the page is up rather than
  holding the mount.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Curation.RosaryAudioGeneration
  alias LumenViae.Rosary
  alias LumenViae.Rosary.{PrayerAudio, Voices}
  alias LumenViae.Storage.S3

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Spoken Rosary")
     |> assign(:voices, Voices.list())
     |> assign(:coverage, nil)
     |> start_coverage()}
  end

  def handle_params(params, _uri, socket) do
    voice =
      case Voices.fetch(params["voice"] || "") do
        {:ok, voice} -> voice
        {:error, _unknown} -> Voices.default()
      end

    {:noreply,
     socket
     |> assign(:voice, voice)
     |> assign(:filter, if(params["show"] == "missing", do: :missing, else: :all))
     |> assign(:version, PrayerAudio.version(voice, PrayerAudio.clips()))
     |> assign(:urls, sign_all(voice))}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, socket |> assign(:coverage, nil) |> start_coverage()}
  end

  def handle_async(:coverage, {:ok, coverage}, socket) do
    by_voice = Map.new(coverage, fn {voice, entries} -> {voice.slug, statuses(entries)} end)
    {:noreply, assign(socket, :coverage, by_voice)}
  end

  def handle_async(:coverage, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:coverage, %{})
     |> put_flash(:error, "Could not check the bucket: #{inspect(reason)}")}
  end

  defp start_coverage(socket) do
    if connected?(socket) do
      start_async(socket, :coverage, fn -> RosaryAudioGeneration.coverage() end)
    else
      socket
    end
  end

  defp statuses(entries), do: Map.new(entries, &{&1.clip.name <> ":#{&1.clip.kind}", &1.status})

  # Signing is a local HMAC, not a request, so the whole catalogue costs
  # nothing to sign. The players use preload="none", so nothing is fetched
  # until somebody presses play.
  defp sign_all(voice) do
    ttl = Rosary.audio_url_ttl()

    Map.new(PrayerAudio.clips(), fn clip ->
      url =
        case S3.generate_presigned_url(PrayerAudio.s3_key(voice, clip), expires_in: ttl) do
          {:ok, url} -> url
          {:error, _reason} -> nil
        end

      {clip_id(clip), url}
    end)
  end

  ## Template helpers

  def clip_id(clip), do: clip.name <> ":#{clip.kind}"

  def status(nil, _voice, _clip), do: :checking
  def status(coverage, voice, clip), do: get_in(coverage, [voice.slug, clip_id(clip)]) || :unknown

  def counts(nil, _voice), do: nil

  def counts(coverage, voice) do
    coverage |> Map.get(voice.slug, %{}) |> Map.values() |> Enum.frequencies()
  end

  def missing_total(nil), do: nil

  def missing_total(coverage) do
    coverage |> Map.values() |> Enum.flat_map(&Map.values/1) |> Enum.count(&(&1 == :missing))
  end

  def visible?(:all, _status), do: true
  def visible?(:missing, status), do: status in [:missing, :unknown]

  @doc "The verses, grouped by mystery in catalogue order, with a heading for each."
  def verse_groups do
    announcements = Map.new(PrayerAudio.announcements(), &{&1.mystery, &1.text})

    PrayerAudio.verses()
    |> Enum.chunk_by(& &1.mystery)
    |> Enum.map(fn [first | _] = verses ->
      {first.mystery, Map.fetch!(announcements, first.mystery), verses}
    end)
  end

  ## Components

  attr :clips, :list, required: true
  attr :coverage, :map, default: nil
  attr :voice, :any, required: true
  attr :urls, :map, required: true
  attr :filter, :atom, required: true

  defp clip_table(assigns) do
    assigns =
      assign(
        assigns,
        :rows,
        for(
          clip <- assigns.clips,
          status = status(assigns.coverage, assigns.voice, clip),
          visible?(assigns.filter, status),
          do: {clip, status}
        )
      )

    ~H"""
    <p :if={@rows == []} class="px-4 py-3 text-xs text-admin-ink-soft">
      Every clip here is recorded.
    </p>
    <table :if={@rows != []} class="admin-table w-full">
      <tbody>
        <tr :for={{clip, status} <- @rows}>
          <td class="w-44 align-top">
            <p class="font-mono text-xs text-admin-ink">{clip.name}</p>
            <p :if={clip.reference} class="text-xs text-admin-ink-faint mt-0.5">
              {clip.reference}
            </p>
            <p class="mt-1"><.status_badge status={status} /></p>
          </td>
          <td class="align-top">
            <p class="text-[0.8125rem] text-admin-ink-soft leading-relaxed max-w-3xl">
              {PrayerAudio.speech_text(clip)}
            </p>
          </td>
          <td class="w-72 align-top">
            <audio
              :if={@urls[clip_id(clip)] && status != :missing}
              controls
              preload="none"
              src={@urls[clip_id(clip)]}
              class="w-full h-8"
            />
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(%{status: :recorded} = assigns),
    do: ~H[<.admin_badge tone="green">Recorded</.admin_badge>]

  defp status_badge(%{status: :missing} = assigns),
    do: ~H[<.admin_badge tone="red">Missing</.admin_badge>]

  defp status_badge(%{status: :checking} = assigns),
    do: ~H[<.admin_badge>Checking</.admin_badge>]

  defp status_badge(assigns),
    do: ~H[<.admin_badge tone="amber" title="S3 could not be asked">Unknown</.admin_badge>]

  attr :verses, :list, required: true
  attr :coverage, :map, default: nil
  attr :voice, :any, required: true

  defp group_status(assigns) do
    assigns =
      assign(
        assigns,
        :missing,
        Enum.count(assigns.verses, &(status(assigns.coverage, assigns.voice, &1) == :missing))
      )

    ~H"""
    <.admin_badge :if={@missing > 0} tone="red">{@missing} missing</.admin_badge>
    """
  end
end
