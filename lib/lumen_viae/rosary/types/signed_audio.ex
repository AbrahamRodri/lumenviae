defmodule LumenViae.Rosary.Types.SignedAudio do
  @moduledoc """
  A presigned audio URL and the moment it stops working.

  The expiry travels with each URL rather than once per response, because
  in GraphQL the same recording can reach a device through two operations
  signed at different moments - a set's detail, and a later refresh of one
  meditation - and a response-wide expiry would then be true of some links
  and not of others.

  `expires_at` is a whole-second UTC instant, which AshGraphql serialises
  as `2026-10-02T12:00:00Z`: the iOS app parses expiries with
  `ISO8601DateFormatter` defaults, which reject fractional seconds.
  """
  use Ash.TypedStruct

  alias LumenViae.Storage.S3

  typed_struct do
    field :url, :string, allow_nil?: false
    field :expires_at, :utc_datetime, allow_nil?: false
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :signed_audio

  @doc """
  Signs `s3_key` for `LumenViae.Rosary.audio_url_ttl/0` seconds. `:error`
  when it cannot be signed, so a caller can leave the recording out rather
  than hand a client a link that will fail.
  """
  def sign(s3_key) do
    ttl = LumenViae.Rosary.audio_url_ttl()

    case S3.generate_presigned_url(s3_key, expires_in: ttl) do
      {:ok, url} -> {:ok, %__MODULE__{url: url, expires_at: expiry(ttl)}}
      {:error, _reason} -> :error
    end
  end

  @doc """
  When a URL signed now for the configured lifetime stops working.
  """
  def expiry(ttl \\ LumenViae.Rosary.audio_url_ttl()) do
    DateTime.utc_now() |> DateTime.add(ttl, :second) |> DateTime.truncate(:second)
  end
end
