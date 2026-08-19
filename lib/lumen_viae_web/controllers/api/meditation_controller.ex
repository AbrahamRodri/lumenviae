defmodule LumenViaeWeb.API.MeditationController do
  @moduledoc """
  Per-meditation endpoints.

  Exists for one reason: a client that stored a presigned URL needs a way
  to get a fresh one. Before this, the only source of meditation audio was
  the whole set detail, so an expired URL meant refetching every meditation
  in the set to replay one of them - and the offline download's resume path
  did not refetch at all, it reused the dead URL off disk.
  """
  use LumenViaeWeb, :controller

  alias LumenViae.Rosary

  action_fallback LumenViaeWeb.API.FallbackController

  @doc """
  Returns a freshly signed URL for one meditation's narration, with the
  moment it expires.

  404s for a meditation that does not exist or is archived, so audio cannot
  outlive the content being withdrawn.
  """
  def audio(conn, %{"id" => id}) do
    with {:ok, meditation} <- fetch_playable_meditation(id),
         {:ok, audio} <- Rosary.fetch_meditation_audio(meditation) do
      conn
      # A presigned URL is single-use in spirit and time-limited in fact.
      # Nothing between here and the device may keep a copy to hand to
      # somebody else after it has expired.
      |> put_resp_header("cache-control", "private, no-store")
      |> render(:audio, id: meditation.id, audio: audio)
    else
      _ -> {:error, :not_found}
    end
  end

  defp fetch_playable_meditation(id) do
    case Integer.parse(to_string(id)) do
      {meditation_id, ""} ->
        case Rosary.get_meditation(meditation_id) do
          nil -> :error
          meditation -> if Rosary.meditation_archived?(meditation), do: :error, else: {:ok, meditation}
        end

      _ ->
        :error
    end
  end
end
