defmodule LumenViaeWeb.Live.Meditations.Edit.NarrationPanel do
  @moduledoc """
  The Narration panel on the meditation edit page: one row per narration
  voice, saying whether the meditation is recorded in it, whether a
  recording is queued or running, and a button to record it.

  The page owns the state: `rows/3` builds the rows from the meditation,
  the voices and the audio jobs in flight, and the page handles the
  `"record_narration"` event with `LumenViae.Curation.AudioRegeneration`.
  """
  use LumenViaeWeb, :html

  alias LumenViae.CentralTime
  alias LumenViae.Rosary.Voices

  @doc """
  One row per voice: `%{voice, narration, job_state}`, where `narration` is
  the recording on record (or nil) and `job_state` the state of a
  recording queued or running for it (or nil). `in_flight` is
  `LumenViae.Curation.AudioJobs.in_flight/0`.
  """
  def rows(meditation, voices, in_flight) do
    filename = filename(meditation)
    jobs = Map.new(in_flight, &{&1.key, &1.state})

    Enum.map(voices, fn voice ->
      %{
        voice: voice,
        narration: Enum.find(meditation.narrations, &(&1.voice == voice.slug)),
        job_state: filename && Map.get(jobs, Voices.narration_key(voice, filename))
      }
    end)
  end

  @doc """
  The S3 keys this meditation's recordings live at, one per voice, so the
  page can tell which audio job events are about it.
  """
  def keys(meditation, voices) do
    case filename(meditation) do
      nil -> []
      filename -> Enum.map(voices, &Voices.narration_key(&1, filename))
    end
  end

  @doc """
  The file the meditation is recorded under, or the one its import named
  for it while no recording has landed: the same choice
  `AudioRegeneration` makes. Nil when it has neither.
  """
  def filename(%{audio_url: url}) when url not in [nil, ""], do: url
  def filename(%{narration_filename: name}) when name not in [nil, ""], do: name
  def filename(_meditation), do: nil

  attr :rows, :list, required: true
  attr :filename, :string, default: nil

  def narration_panel(assigns) do
    ~H"""
    <.panel
      title="Narration"
      description="Records the saved text, so save your edits first. Each recording is an ElevenLabs call; Record again pays for a second take even when nothing changed."
      class="mt-5"
      flush
    >
      <.empty_state :if={is_nil(@filename)} class="m-4">
        No audio filename: give the meditation one above, or import it, before it can be recorded.
      </.empty_state>

      <table :if={@filename} class="admin-table w-full">
        <thead>
          <tr>
            <th>Voice</th>
            <th>Status</th>
            <th class="text-right">Action</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @rows}>
            <td>
              <span class="font-medium">{row.voice.name}</span>
              <span class="text-admin-ink-faint text-xs ml-1">{row.voice.slug}</span>
            </td>
            <td>
              <.status row={row} />
            </td>
            <td class="text-right">
              <button
                :if={is_nil(row.job_state) and is_nil(row.narration)}
                type="button"
                phx-click="record_narration"
                phx-value-voice={row.voice.slug}
                class="admin-btn admin-btn-secondary"
              >
                Record
              </button>
              <button
                :if={is_nil(row.job_state) and row.narration}
                type="button"
                phx-click="record_narration"
                phx-value-voice={row.voice.slug}
                phx-value-force="true"
                data-confirm={"Record #{row.voice.name} again? ElevenLabs is paid for a new take even if the text has not changed."}
                class="admin-btn admin-btn-ghost"
              >
                Record again
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </.panel>
    """
  end

  attr :row, :map, required: true

  defp status(%{row: %{job_state: state}} = assigns) when state in ["executing"] do
    ~H"""
    <.admin_badge tone="navy">Recording</.admin_badge>
    """
  end

  defp status(%{row: %{job_state: state}} = assigns) when is_binary(state) do
    ~H"""
    <.admin_badge tone="amber" title={"Job state: #{@row.job_state}"}>Queued</.admin_badge>
    """
  end

  defp status(%{row: %{narration: nil}} = assigns) do
    ~H"""
    <.admin_badge tone="red">Not recorded</.admin_badge>
    """
  end

  defp status(assigns) do
    ~H"""
    <.admin_badge tone="green">Recorded</.admin_badge>
    <span :if={@row.narration.generated_at} class="text-xs text-admin-ink-soft ml-1">
      {CentralTime.format_short(@row.narration.generated_at)}
    </span>
    """
  end
end
