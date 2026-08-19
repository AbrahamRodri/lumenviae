defmodule LumenViae.Storage.S3 do
  @moduledoc """
  AWS S3 storage helper for the two buckets this app uses.

  `lumenviae-audio` is private: narration is paid for and is reached only
  through a pre-signed URL with a lifetime. `lumenviae-images` is public
  read: artwork has to survive in a client-side cache for offline prayer, so
  it is served from a stable unsigned URL that never expires. The two are
  separate buckets so a mistake in one policy cannot expose the other.
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
  def upload_audio(audio_binary, s3_key, opts \\ [])
      when is_binary(audio_binary) and is_binary(s3_key) do
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

  @public_cache_control "public, max-age=31536000, immutable"

  @doc """
  Uploads a binary to the public assets bucket.

  Public assets are artwork. The iOS app caches them to disk for offline
  prayer, so they are read from a stable unsigned URL rather than a
  presigned one, and the bucket policy is what makes them readable. This
  never sets an object ACL: the bucket blocks public ACLs, and the scoped
  IAM user is denied every ACL action outright, so an ACL here would only
  turn a working upload into an AccessDenied.

  Keys are content-addressed by the caller (see
  `LumenViae.Curation.ArtworkUpload`), so no object ever changes under a
  key it already occupies. That is what lets the cache headers below claim
  a year and immutability with no invalidation story anywhere in the chain.

  ## Parameters

    * `binary` - the image bytes
    * `key` - the S3 object key, e.g. "sets/27/8f21c4d9e0b3a7f6.jpg"
    * `opts` - optional keyword list of options:
      * `:bucket` - S3 bucket name (default: from `:aws_s3_public_bucket`)
      * `:content_type` - Content type (default: "image/jpeg")
      * `:cache_control` - Cache-Control header (default: one immutable year)

  ## Returns

    * `{:ok, key}` - Successfully uploaded, returns the S3 key
    * `{:error, reason}` - Error tuple if the upload fails

  ## Examples

      iex> LumenViae.Storage.S3.upload_public(bytes, "sets/27/8f21c4d9e0b3a7f6.jpg")
      {:ok, "sets/27/8f21c4d9e0b3a7f6.jpg"}
  """
  @spec upload_public(binary, String.t(), keyword) :: {:ok, String.t()} | {:error, term}
  def upload_public(binary, key, opts \\ [])

  def upload_public(_binary, key, _opts) when key in [nil, ""], do: {:error, :invalid_key}

  def upload_public(binary, key, opts) when is_binary(binary) and is_binary(key) do
    bucket = opts[:bucket] || public_bucket()
    content_type = opts[:content_type] || "image/jpeg"
    cache_control = opts[:cache_control] || @public_cache_control

    case validate_aws_config() do
      :ok ->
        try do
          Logger.info("Uploading public asset to S3: #{key} (#{byte_size(binary)} bytes)")

          result =
            ExAws.S3.put_object(bucket, key, binary,
              content_type: content_type,
              cache_control: cache_control
            )
            |> ExAws.request()

          case result do
            {:ok, _response} ->
              Logger.info("Successfully uploaded public asset to S3: #{key}")
              {:ok, key}

            {:error, reason} ->
              Logger.error("Failed to upload public asset to S3 #{key}: #{inspect(reason)}")
              {:error, reason}
          end
        rescue
          e ->
            Logger.error("Exception uploading public asset to S3 #{key}: #{Exception.message(e)}")
            {:error, :upload_failed}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Stable, unsigned, cacheable URL for an object in the public assets bucket.

  Unlike `generate_presigned_url/2` this signs nothing and expires never:
  artwork lives in a public bucket precisely so the client can cache it and
  still show it during offline prayer. Returns nil for a nil or empty key,
  so a set with no artwork renders a null in the API rather than a URL that
  404s.

  The scheme, host and port come from the same `config :ex_aws, :s3` the
  presigner is configured from, rather than from a hardcoded virtual-hosted
  template: that config carries no `%{bucket}` placeholder, so ExAws
  addresses buckets path-style, and a second builder that assumed
  virtual-hosted would drift the first time the host changed. Credentials
  are deliberately not resolved - nothing here is signed - which keeps this
  a pure function with no lookup of an instance role or an AWS CLI
  profile.

  Setting PUBLIC_ASSET_BASE_URL moves artwork behind a CDN without touching
  the database, because only keys are ever stored.
  """
  @spec public_url(String.t() | nil) :: String.t() | nil
  def public_url(key) when key in [nil, ""], do: nil

  def public_url(key) when is_binary(key) do
    base = Application.get_env(:lumen_viae, :public_asset_base_url) || bucket_base_url()

    String.trim_trailing(base, "/") <> "/" <> encode_key(key)
  end

  defp public_bucket, do: Application.get_env(:lumen_viae, :aws_s3_public_bucket)

  defp bucket_base_url do
    config = Application.get_env(:ex_aws, :s3, [])
    scheme = config[:scheme] || "https://"
    host = config[:host] || "s3.amazonaws.com"

    "#{scheme}#{host}#{port_component(config)}/#{public_bucket()}"
  end

  # 80 and 443 are implied by the scheme, and ExAws omits them when it signs;
  # spelling one out here would only bake noise into every cached client copy.
  defp port_component(config) do
    case config[:port] do
      port when port in [nil, 80, "80", 443, "443"] -> ""
      port -> ":#{port}"
    end
  end

  # Keys are ASCII by construction today, but a public URL is a contract with
  # clients that cache it, and one space in a hand-uploaded key would
  # otherwise hand out a broken link.
  defp encode_key(key), do: URI.encode(key, &(URI.char_unreserved?(&1) or &1 == ?/))

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
