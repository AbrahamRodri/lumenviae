defmodule LumenViae.Audio.Pipeline do
  @moduledoc """
  Shared narration pipeline: prepares stored meditation content for TTS
  (`LumenViae.Audio.TtsText`), generates audio with ElevenLabs, and uploads
  the result to S3.

  Every ElevenLabs call goes through this module so the pause transforms are
  applied to the text sent to the API and never anywhere else; stored
  content is never narrated verbatim.

  ElevenLabs in particular fails transiently, so both the generation call
  and the S3 upload are retried with increasing backoff before giving up.
  Errors tagged `{:fatal, message}` (bad API key, missing credentials, and
  the like) are never retried because they cannot succeed.

  Used by `LumenViae.Meditations.CsvImport` and
  `LumenViae.Meditations.AudioRegeneration`.
  """

  alias LumenViae.Audio.{ElevenLabs, TtsText}
  alias LumenViae.Storage.S3

  require Logger

  @attempts 3
  @retry_base_delay_ms 2_000

  @doc """
  Generates narration for stored meditation content and uploads it to S3
  under `s3_key`, replacing any existing object at that key.

  The text sent to ElevenLabs is derived with
  `TtsText.to_speech_text(content, tts_annotations)`.

  Options:

    * `:on_retry` - a `fn attempt, max -> ... end` called before each retry

  Returns `{:ok, s3_key}` or `{:error, reason}`.
  """
  def generate_and_upload(content, tts_annotations, s3_key, opts \\ []) do
    on_retry = Keyword.get(opts, :on_retry, fn _attempt, _max -> :ok end)
    text = TtsText.to_speech_text(content, tts_annotations || [])

    with {:ok, audio_binary} <-
           with_retries(fn -> ElevenLabs.generate_audio(text) end, "ElevenLabs", s3_key, on_retry),
         {:ok, s3_key} <-
           with_retries(fn -> S3.upload_audio(audio_binary, s3_key) end, "S3", s3_key, on_retry) do
      {:ok, s3_key}
    else
      {:error, reason} = error ->
        Logger.error("Audio generation/upload failed: #{inspect(reason)}")
        error
    end
  end

  defp with_retries(fun, label, filename, on_retry, attempt \\ 1) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        case fatal_reason(reason) do
          nil ->
            maybe_retry(fun, label, filename, on_retry, attempt, reason)

          message ->
            Logger.error("#{label} failed for #{filename} (not retryable): #{message}")
            {:error, message}
        end
    end
  end

  defp maybe_retry(fun, label, filename, on_retry, attempt, reason)
       when attempt < @attempts do
    delay = retry_delay(attempt)

    Logger.warning(
      "#{label} failed for #{filename} (attempt #{attempt} of #{@attempts}): " <>
        "#{inspect(reason)}. Retrying in #{delay}ms"
    )

    on_retry.(attempt + 1, @attempts)
    Process.sleep(delay)
    with_retries(fun, label, filename, on_retry, attempt + 1)
  end

  defp maybe_retry(_fun, label, filename, _on_retry, _attempt, reason) do
    Logger.error(
      "#{label} failed for #{filename} after #{@attempts} attempts: #{inspect(reason)}"
    )

    {:error, reason}
  end

  defp fatal_reason({:fatal, message}), do: message

  defp fatal_reason(:missing_credentials),
    do: "AWS credentials not configured (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY)"

  defp fatal_reason(_reason), do: nil

  defp retry_delay(attempt) do
    base =
      Application.get_env(:lumen_viae, :audio_retry_base_delay_ms, @retry_base_delay_ms)

    base * attempt
  end
end
