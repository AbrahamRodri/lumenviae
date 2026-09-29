defmodule LumenViae.Rosary.Voices do
  @moduledoc """
  The narration voices a meditation can be heard in.

  A value module: it reads the `:narration_voices` list from application
  config and hands out plain `%LumenViae.Rosary.Voices.Voice{}` structs, so
  any layer may call it. The list is configuration rather than a table
  because a voice is not data anyone edits in the admin - adding one is a
  config line followed by a regeneration run, and removing one is the
  reverse.

  Each voice has:

    * `slug` - the stable identifier clients and S3 keys use (`"female"`)
    * `name` - what the app shows in its picker
    * `description` - one line under the name
    * `eleven_labs_voice_id` - which ElevenLabs voice synthesizes it
    * `model_id` - the ElevenLabs model it is synthesized with; the pause
      syntax follows it (`LumenViae.Audio.ElevenLabs.pause_style/1`)
    * `voice_settings` - the stability, similarity_boost, style and
      use_speaker_boost sent with every request for this voice
    * `default` - the voice the legacy single `audio_url` plays and the
      website uses; exactly one voice carries it
    * `hidden` - a retired voice: its files and rows stay and its slug
      still resolves for tooling (`get/1`, `fetch/1`), but it is left out
      of `list/0`, so no client is offered it and no import records it
    * `replaced_by` - for a hidden voice, the voice a client asking for it
      by slug hears instead (`resolve/1`)
    * `rosary_audio_from` - clip kinds (`:prayer`, `:announcement`,
      `:verse`, `:book`) this voice has not recorded for the spoken Rosary,
      each mapped to the slug of the voice whose recordings stand in. See
      `LumenViae.Rosary.PrayerAudio.served_voice/2`.

  ## S3 layout

  Every meditation with narration has one filename (`meditations.audio_url`,
  e.g. `Glorious-Fulton-1.mp3`) and one object per voice, at
  `voices/<slug>/<filename>`. `narration_key/2` is the only place that
  layout is spelled out.
  """

  defmodule Voice do
    @moduledoc "One narration voice. See `LumenViae.Rosary.Voices`."
    @enforce_keys [:slug, :name, :eleven_labs_voice_id]
    defstruct [
      :slug,
      :name,
      :eleven_labs_voice_id,
      description: nil,
      model_id: "eleven_v3",
      voice_settings: %{stability: 0.5, similarity_boost: 0.75},
      default: false,
      hidden: false,
      replaced_by: nil,
      rosary_audio_from: %{}
    ]

    @type t :: %__MODULE__{
            slug: String.t(),
            name: String.t(),
            description: String.t() | nil,
            eleven_labs_voice_id: String.t(),
            model_id: String.t(),
            voice_settings: map,
            default: boolean,
            hidden: boolean,
            replaced_by: String.t() | nil,
            rosary_audio_from: %{optional(atom) => String.t()}
          }
  end

  @doc """
  Every voice a client is offered, in display order, the default first.
  Hidden voices are left out; `all/0` includes them.
  """
  @spec list() :: [Voice.t()]
  def list, do: Enum.reject(all(), & &1.hidden)

  @doc """
  Every configured voice, hidden ones included, the default first.
  """
  @spec all() :: [Voice.t()]
  def all do
    voices =
      Application.get_env(:lumen_viae, :narration_voices, []) |> Enum.map(&struct!(Voice, &1))

    case Enum.split_with(voices, &(&1.default and not &1.hidden)) do
      {[], all} -> all
      {[default | _], others} -> [default | Enum.reject(others, &(&1.slug == default.slug))]
    end
  end

  @doc """
  The voice the single `audio_url` fields play. Raises when no voice is
  configured: narration without a voice is a misconfiguration to fail on
  loudly, not a nil to carry around.
  """
  @spec default() :: Voice.t()
  def default do
    case list() do
      [first | _] -> first
      [] -> raise "no narration voices configured (config :lumen_viae, :narration_voices)"
    end
  end

  @doc """
  The configured slugs, default first.
  """
  @spec slugs() :: [String.t()]
  def slugs, do: Enum.map(list(), & &1.slug)

  @doc """
  The voice with this slug, hidden or not, or nil.
  """
  @spec get(String.t() | nil) :: Voice.t() | nil
  def get(slug) when is_binary(slug), do: Enum.find(all(), &(&1.slug == slug))
  def get(_slug), do: nil

  @doc """
  `{:ok, voice}` for a configured slug, `{:error, :unknown_voice}` otherwise.
  """
  @spec fetch(String.t() | nil) :: {:ok, Voice.t()} | {:error, :unknown_voice}
  def fetch(slug) do
    case get(slug) do
      nil -> {:error, :unknown_voice}
      voice -> {:ok, voice}
    end
  end

  @doc """
  The voice a client asking for `slug` hears: that voice when it is
  offered, and for a hidden voice the one it was `replaced_by` (or the
  default, when it names none). `{:error, :unknown_voice}` for a slug that
  was never configured.

  Every client-facing lookup goes through here, so a device or a link that
  still carries a retired slug keeps working and hears its successor.
  """
  @spec resolve(String.t() | nil) :: {:ok, Voice.t()} | {:error, :unknown_voice}
  def resolve(slug) do
    case get(slug) do
      nil ->
        {:error, :unknown_voice}

      %Voice{hidden: false} = voice ->
        {:ok, voice}

      %Voice{replaced_by: next} ->
        {:ok, (next && Enum.find(list(), &(&1.slug == next))) || default()}
    end
  end

  @doc """
  Whether this slug names a configured voice.
  """
  @spec valid?(String.t() | nil) :: boolean
  def valid?(slug), do: get(slug) != nil

  @doc """
  The S3 key for one voice's narration of a meditation whose audio filename
  is `filename`: `voices/<slug>/<filename>`.

  The filename is the meditation's `audio_url` column - assigned at import,
  unique across meditations - and stays the same for every voice, so the
  objects for one meditation sit at the same relative path under each voice
  prefix.
  """
  @spec narration_key(Voice.t() | String.t(), String.t()) :: String.t()
  def narration_key(%Voice{slug: slug}, filename), do: narration_key(slug, filename)

  def narration_key(slug, filename) when is_binary(slug) and is_binary(filename) do
    "voices/#{slug}/#{filename}"
  end
end
