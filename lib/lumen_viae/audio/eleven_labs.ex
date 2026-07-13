defmodule LumenViae.Audio.ElevenLabs do
  @moduledoc """
  Client for ElevenLabs text-to-speech API.
  Generates audio from meditation text content.

  ## Errors

  Failures are returned as tagged tuples so callers can decide what is worth
  retrying:

    * `{:error, message}` - transient failure (timeout, connection reset,
      rate limit, ElevenLabs 5xx); retrying may succeed
    * `{:error, {:fatal, message}}` - permanent failure (missing
      configuration, rejected API key, invalid request); retrying cannot
      succeed

  ## Configuration

  Request options can be overridden (or a `Req.Test` plug injected in tests)
  via application config:

      config :lumen_viae, :eleven_labs_req_options, receive_timeout: 60_000
  """

  require Logger

  @api_base_url "https://api.elevenlabs.io/v1"

  # Synthesizing meditation-length text regularly takes 30-60+ seconds, far
  # above Req's 15 second default receive timeout. The old default was the
  # main source of "Failed to connect to ElevenLabs API" import errors.
  @receive_timeout_ms 120_000
  @connect_timeout_ms 10_000

  @doc """
  Generates audio from text using ElevenLabs API.

  ## Parameters
    - text: The meditation content to convert to speech
    - voice_id: The ElevenLabs voice ID (defaults to config value)

  ## Returns
    - {:ok, audio_binary} on success
    - {:error, reason} on transient failure
    - {:error, {:fatal, reason}} on permanent failure

  ## Examples
      iex> generate_audio("Hail Mary, full of grace...", "RTFg9niKcgGLDwa3RFlz")
      {:ok, <<...audio binary...>>}
  """
  def generate_audio(text, voice_id \\ nil) do
    voice_id = voice_id || get_voice_id()
    api_key = get_api_key()

    cond do
      blank?(api_key) ->
        {:error, {:fatal, "ElevenLabs API key not configured (ELEVEN_LABS_API_KEY)"}}

      blank?(voice_id) ->
        {:error, {:fatal, "ElevenLabs voice ID not configured"}}

      true ->
        do_generate_audio(text, voice_id, api_key)
    end
  end

  defp do_generate_audio(text, voice_id, api_key) do
    url = "#{@api_base_url}/text-to-speech/#{voice_id}"

    body =
      Jason.encode!(%{
        text: text,
        # The audio pipeline relies on <break time="Ns" /> tags for
        # narration pauses; eleven_multilingual_v2 honors them (all
        # ElevenLabs models except Eleven V3 do, capped at 3 seconds).
        model_id: "eleven_multilingual_v2",
        output_format: "mp3_44100_128",
        voice_settings: %{
          stability: 0.5,
          similarity_boost: 0.75
        }
      })

    request_options =
      [
        headers: [{"xi-api-key", api_key}, {"content-type", "application/json"}],
        body: body,
        receive_timeout: @receive_timeout_ms,
        connect_options: [timeout: @connect_timeout_ms],
        # Retries (with progress reporting) are owned by the import layer.
        retry: false
      ]
      |> Keyword.merge(Application.get_env(:lumen_viae, :eleven_labs_req_options, []))

    Logger.info("Generating audio with ElevenLabs for #{String.length(text)} characters")

    case Req.post(url, request_options) do
      {:ok, %Req.Response{status: 200, body: audio_binary}}
      when is_binary(audio_binary) and byte_size(audio_binary) > 0 ->
        Logger.info("Successfully generated audio (#{byte_size(audio_binary)} bytes)")
        {:ok, audio_binary}

      {:ok, %Req.Response{status: 200}} ->
        {:error, "ElevenLabs returned an empty audio response"}

      {:ok, %Req.Response{status: status, body: error_body}} ->
        classify_error(status, error_body)

      {:error, exception} ->
        message = transport_error_message(exception, request_options)
        Logger.error(message)
        {:error, message}
    end
  end

  defp classify_error(status, error_body) do
    detail = error_detail(error_body)
    Logger.error("ElevenLabs API error (status #{status}): #{detail}")

    cond do
      status in [401, 403] ->
        {:error, {:fatal, "ElevenLabs rejected the API key (status #{status}): #{detail}"}}

      status in [408, 429] ->
        {:error, "ElevenLabs throttled the request (status #{status}): #{detail}"}

      status in 400..499 ->
        {:error, {:fatal, "ElevenLabs rejected the request (status #{status}): #{detail}"}}

      true ->
        {:error, "ElevenLabs server error (status #{status}): #{detail}"}
    end
  end

  defp error_detail(%{"detail" => %{"message" => message}}) when is_binary(message), do: message
  defp error_detail(%{"detail" => detail}) when is_binary(detail), do: detail
  defp error_detail(body) when is_binary(body), do: String.slice(body, 0, 200)
  defp error_detail(body), do: body |> inspect() |> String.slice(0, 200)

  defp transport_error_message(%Req.TransportError{reason: :timeout}, request_options) do
    timeout_s = div(Keyword.fetch!(request_options, :receive_timeout), 1000)
    "ElevenLabs did not respond within #{timeout_s}s (synthesis timed out)"
  end

  defp transport_error_message(exception, _request_options) when is_exception(exception) do
    "ElevenLabs connection failed: #{Exception.message(exception)}"
  end

  defp transport_error_message(other, _request_options) do
    "ElevenLabs request failed: #{inspect(other)}"
  end

  defp blank?(value), do: value in [nil, ""]

  defp get_api_key do
    Application.get_env(:lumen_viae, :eleven_labs_api_key)
  end

  defp get_voice_id do
    Application.get_env(:lumen_viae, :eleven_labs_voice_id)
  end
end
