defmodule LumenViae.Audio.ElevenLabs do
  @moduledoc """
  Client for ElevenLabs text-to-speech API.
  Generates audio from meditation text content.
  """

  require Logger

  @api_base_url "https://api.elevenlabs.io/v2"

  @doc """
  Generates audio from text using ElevenLabs API.

  ## Parameters
    - text: The meditation content to convert to speech
    - voice_id: The ElevenLabs voice ID (defaults to config value)

  ## Returns
    - {:ok, audio_binary} on success
    - {:error, reason} on failure

  ## Examples
      iex> generate_audio("Hail Mary, full of grace...", "RTFg9niKcgGLDwa3RFlz")
      {:ok, <<...audio binary...>>}
  """
  def generate_audio(text, voice_id \\ nil) do
    voice_id = voice_id || get_voice_id()
    api_key = get_api_key()

    if is_nil(api_key) or api_key == "" do
      {:error, "ElevenLabs API key not configured"}
    else
      do_generate_audio(text, voice_id, api_key)
    end
  end

  defp do_generate_audio(text, voice_id, api_key) do
    url = "#{@api_base_url}/text-to-speech/#{voice_id}"

    headers = [
      {"xi-api-key", api_key},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        text: text,
        model_id: "eleven_monolingual_v1",
        output_format: "mp3_44100_128",
        voice_settings: %{
          stability: 0.5,
          similarity_boost: 0.75
        }
      })

    Logger.info("Generating audio with ElevenLabs for #{String.length(text)} characters")

    case Req.post(url, headers: headers, body: body) do
      {:ok, %Req.Response{status: 200, body: audio_binary}} ->
        Logger.info("Successfully generated audio (#{byte_size(audio_binary)} bytes)")
        {:ok, audio_binary}

      {:ok, %Req.Response{status: status, body: error_body}} ->
        Logger.error("ElevenLabs API error (status #{status}): #{inspect(error_body)}")
        {:error, "ElevenLabs API returned status #{status}"}

      {:error, exception} ->
        Logger.error("ElevenLabs API request failed: #{inspect(exception)}")
        {:error, "Failed to connect to ElevenLabs API"}
    end
  end

  defp get_api_key do
    Application.get_env(:lumen_viae, :eleven_labs_api_key)
  end

  defp get_voice_id do
    Application.get_env(:lumen_viae, :eleven_labs_voice_id)
  end
end
