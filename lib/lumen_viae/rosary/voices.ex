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
    * `default` - the voice the legacy single `audio_url` plays and the
      website uses; exactly one voice carries it

  ## S3 layout

  Every meditation with narration has one filename (`meditations.audio_url`,
  e.g. `Glorious-Fulton-1.mp3`) and one object per voice, at
  `voices/<slug>/<filename>`. `narration_key/2` is the only place that
  layout is spelled out.
  """

  defmodule Voice do
    @moduledoc "One narration voice. See `LumenViae.Rosary.Voices`."
    @enforce_keys [:slug, :name, :eleven_labs_voice_id]
    defstruct [:slug, :name, :eleven_labs_voice_id, description: nil, default: false]

    @type t :: %__MODULE__{
            slug: String.t(),
            name: String.t(),
            description: String.t() | nil,
            eleven_labs_voice_id: String.t(),
            default: boolean
          }
  end

  @doc """
  Every configured voice, in display order, the default first.
  """
  @spec list() :: [Voice.t()]
  def list do
    voices =
      Application.get_env(:lumen_viae, :narration_voices, []) |> Enum.map(&struct!(Voice, &1))

    case Enum.split_with(voices, & &1.default) do
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
  The voice with this slug, or nil.
  """
  @spec get(String.t() | nil) :: Voice.t() | nil
  def get(slug) when is_binary(slug), do: Enum.find(list(), &(&1.slug == slug))
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
