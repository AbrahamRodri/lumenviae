defmodule LumenViae.Curation.ArtworkUpload do
  @moduledoc """
  Validates a painting and puts it in the public assets bucket under a
  content-addressed key.

  Sits above the domain like `LumenViae.Curation.CsvImport`: the admin
  upload UI and any future entry point come through here, so no caller can
  invent its own naming scheme or quietly skip a rule.

  Keys are `sets/27/8f21c4d9e0b3a7f6.jpg`, where the hex is the first 16
  characters of the SHA-256 of the bytes. Replacing a painting therefore
  writes a new key, so the URL changes and every cache in the chain - S3,
  any CDN, the client's `URLCache`, the iOS offline manifest - invalidates
  itself with no purge to remember. The cost is that the superseded object
  stays behind; it is deliberately not deleted, because a client holding
  the old URL that has not fetched it yet would 404 and drop to the bundled
  painting. Orphans are a few megabytes, and there is no sweep task.

  Nothing here resizes or re-encodes: the production image carries no image
  library (see `LumenViae.Images.Inspector`), so the rules below are the
  only lever, and a painting that fails them has to be fixed before upload.
  """

  alias LumenViae.Images.Inspector
  alias LumenViae.Storage.S3

  @max_bytes 12 * 1024 * 1024
  @min_short_side 1200
  @max_long_side 4000

  @type scope :: :set | :meditation

  @doc """
  Validates and uploads a painting, returning the fields the schema's
  managed changeset writes.

  Returns `{:ok, %{"image_key" => key, "image_width" => w,
  "image_height" => h, "image_updated_at" => ts}}` - string keys, so the
  result drops straight into an Ecto changeset beside form params - or
  `{:error, message}` with a message written for the curator looking at the
  admin form, not for a log.
  """
  @spec upload(binary, scope, pos_integer) :: {:ok, map} | {:error, String.t()}
  def upload(binary, scope, id) do
    with {:ok, %{key: key, info: info}} <- prepare(binary, scope, id) do
      case S3.upload_public(binary, key) do
        {:ok, key} -> {:ok, managed_fields(key, info)}
        {:error, reason} -> {:error, "The image could not be uploaded: #{describe(reason)}."}
      end
    end
  end

  @doc """
  Everything `upload/3` does except the PUT: applies the rules and derives
  the key.

  Public so the rules and the naming can be tested and previewed without a
  network round trip, since the key is the cache-invalidation contract and
  is otherwise only observable on a successful upload.
  """
  @spec prepare(binary, scope, pos_integer) ::
          {:ok, %{key: String.t(), info: Inspector.info()}} | {:error, String.t()}
  def prepare(binary, scope, id) when is_binary(binary) and scope in [:set, :meditation] do
    with :ok <- check_size(binary),
         {:ok, info} <- read_header(binary),
         :ok <- check_format(info),
         :ok <- check_colour(info),
         :ok <- check_dimensions(info) do
      {:ok, %{key: key(binary, scope, id), info: info}}
    end
  end

  @doc "The rules, as a sentence, for the admin form's help text."
  def rules do
    "JPEG, at most #{div(@max_bytes, 1024 * 1024)} MB, " <>
      "shortest side at least #{@min_short_side}px, " <>
      "longest side at most #{@max_long_side}px, not CMYK."
  end

  defp check_size(binary) when byte_size(binary) <= @max_bytes, do: :ok

  defp check_size(binary) do
    {:error,
     "The image is #{megabytes(byte_size(binary))} MB. The limit is " <>
       "#{div(@max_bytes, 1024 * 1024)} MB - export it again at a lower JPEG quality."}
  end

  defp read_header(binary) do
    case Inspector.inspect(binary) do
      {:ok, info} ->
        {:ok, info}

      {:error, :unsupported_format} ->
        {:error, "That file is not a JPEG. Export the painting as a JPEG and upload it again."}

      {:error, :malformed} ->
        {:error,
         "The file starts like an image but its header could not be read. It is probably " <>
           "truncated - try exporting and uploading it again."}
    end
  end

  defp check_format(%{format: :jpeg}), do: :ok

  defp check_format(%{format: format}) do
    {:error,
     "Artwork is served as JPEG, and this is a #{String.upcase(to_string(format))}. " <>
       "Export the painting as a JPEG and upload it again."}
  end

  # A four-component JPEG is CMYK, which iOS renders with visibly shifted
  # colour. Nothing on the server can convert it, so it has to be refused.
  defp check_colour(%{format: :jpeg, components: 4}) do
    {:error,
     "The image is CMYK, which renders with shifted colour on iOS. " <>
       "Convert it to sRGB and upload it again."}
  end

  defp check_colour(_info), do: :ok

  defp check_dimensions(%{width: width, height: height}) do
    short = min(width, height)
    long = max(width, height)

    cond do
      short < @min_short_side ->
        {:error,
         "The shortest side is #{short}px. Artwork needs at least #{@min_short_side}px so the " <>
           "set-detail hero stays sharp on a retina screen."}

      long > @max_long_side ->
        {:error,
         "The longest side is #{long}px. The limit is #{@max_long_side}px - nothing can be " <>
           "resized on the server, so scale it down before uploading."}

      true ->
        :ok
    end
  end

  defp key(binary, scope, id) do
    digest =
      :sha256
      |> :crypto.hash(binary)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    "#{prefix(scope)}/#{id}/#{digest}.jpg"
  end

  defp prefix(:set), do: "sets"
  defp prefix(:meditation), do: "meditations"

  defp managed_fields(key, info) do
    %{
      "image_key" => key,
      "image_width" => info.width,
      "image_height" => info.height,
      "image_updated_at" => DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  defp megabytes(bytes), do: :erlang.float_to_binary(bytes / (1024 * 1024), decimals: 1)

  defp describe(:missing_credentials), do: "AWS credentials are not configured"
  defp describe(reason), do: inspect(reason)
end
