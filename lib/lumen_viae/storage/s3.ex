defmodule LumenViae.Storage.S3 do
  @moduledoc """
  AWS S3 storage helper for generating pre-signed URLs for private audio files.
  """

  require Logger

  @doc """
  Generates a pre-signed URL for a private S3 object.

  The URL is valid for 1 hour (3600 seconds) and allows GET access to the object.

  ## Parameters

    * `s3_key` - The S3 object key (e.g., "meditation1.mp3" or "joyful/annunciation.mp3")
    * `opts` - Optional keyword list of options:
      * `:expires_in` - Expiration time in seconds (default: 3600, i.e., 1 hour)
      * `:bucket` - S3 bucket name (default: from config)

  ## Returns

    * `{:ok, url}` - Pre-signed HTTPS URL string
    * `{:error, reason}` - Error tuple if URL generation fails

  ## Examples

      iex> LumenViae.Storage.S3.generate_presigned_url("meditation1.mp3")
      {:ok, "https://lumenviae-audio.s3.us-east-2.amazonaws.com/meditation1.mp3?..."}

      iex> LumenViae.Storage.S3.generate_presigned_url("joyful/annunciation.mp3", expires_in: 7200)
      {:ok, "https://lumenviae-audio.s3.us-east-2.amazonaws.com/joyful/annunciation.mp3?..."}

      iex> LumenViae.Storage.S3.generate_presigned_url(nil)
      {:error, :invalid_key}
  """
  def generate_presigned_url(s3_key, opts \\ [])

  def generate_presigned_url(nil, _opts), do: {:error, :invalid_key}
  def generate_presigned_url("", _opts), do: {:error, :invalid_key}

  def generate_presigned_url(s3_key, opts) when is_binary(s3_key) do
    bucket = opts[:bucket] || Application.get_env(:lumen_viae, :aws_s3_bucket)
    expires_in = opts[:expires_in] || 3600

    # Validate AWS credentials are configured
    case validate_aws_config() do
      :ok ->
        try do
          config = ExAws.Config.new(:s3)

          presigned_url =
            ExAws.S3.presigned_url(config, :get, bucket, s3_key, expires_in: expires_in)

          case presigned_url do
            {:ok, url} ->
              {:ok, url}

            {:error, reason} ->
              Logger.error("Failed to generate pre-signed URL for #{s3_key}: #{inspect(reason)}")
              {:error, reason}
          end
        rescue
          e ->
            Logger.error(
              "Exception generating pre-signed URL for #{s3_key}: #{Exception.message(e)}"
            )

            {:error, :generation_failed}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generates a pre-signed URL and returns the URL string or nil on error.

  This is a convenience function that unwraps the result tuple.

  ## Examples

      iex> LumenViae.Storage.S3.generate_presigned_url!("meditation1.mp3")
      "https://lumenviae-audio.s3.us-east-2.amazonaws.com/meditation1.mp3?..."

      iex> LumenViae.Storage.S3.generate_presigned_url!(nil)
      nil
  """
  def generate_presigned_url!(s3_key, opts \\ []) do
    case generate_presigned_url(s3_key, opts) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  @doc """
  Uploads audio binary data to S3.

  ## Parameters

    * `audio_binary` - The audio file content as binary data
    * `s3_key` - The S3 object key (filename) to store the audio
    * `opts` - Optional keyword list of options:
      * `:bucket` - S3 bucket name (default: from config)
      * `:content_type` - Content type (default: "audio/mpeg")

  ## Returns

    * `{:ok, s3_key}` - Successfully uploaded, returns the S3 key
    * `{:error, reason}` - Error tuple if upload fails

  ## Examples

      iex> audio_binary = File.read!("meditation.mp3")
      iex> LumenViae.Storage.S3.upload_audio(audio_binary, "joyful_1_annunciation.mp3")
      {:ok, "joyful_1_annunciation.mp3"}
  """
  def upload_audio(audio_binary, s3_key, opts \\ []) when is_binary(audio_binary) and is_binary(s3_key) do
    bucket = opts[:bucket] || Application.get_env(:lumen_viae, :aws_s3_bucket)
    content_type = opts[:content_type] || "audio/mpeg"

    case validate_aws_config() do
      :ok ->
        try do
          Logger.info("Uploading audio to S3: #{s3_key} (#{byte_size(audio_binary)} bytes)")

          result =
            ExAws.S3.put_object(bucket, s3_key, audio_binary, content_type: content_type)
            |> ExAws.request()

          case result do
            {:ok, _response} ->
              Logger.info("Successfully uploaded audio to S3: #{s3_key}")
              {:ok, s3_key}

            {:error, reason} ->
              Logger.error("Failed to upload audio to S3 #{s3_key}: #{inspect(reason)}")
              {:error, reason}
          end
        rescue
          e ->
            Logger.error("Exception uploading audio to S3 #{s3_key}: #{Exception.message(e)}")
            {:error, :upload_failed}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper to validate AWS configuration
  defp validate_aws_config do
    config = ExAws.Config.new(:s3)

    cond do
      is_nil(config.access_key_id) or config.access_key_id == "" ->
        Logger.warning("AWS_ACCESS_KEY_ID is not configured")
        {:error, :missing_credentials}

      is_nil(config.secret_access_key) or config.secret_access_key == "" ->
        Logger.warning("AWS_SECRET_ACCESS_KEY is not configured")
        {:error, :missing_credentials}

      true ->
        :ok
    end
  end
end
