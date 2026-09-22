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
  voice it is in and the moment it expires.

  `?voice=<slug>` picks the voice; without it the default voice is served,
  or whichever voice has recorded the meditation when the default has not.
  An unknown slug is a 400, so a client with a stale voice list learns it is
  stale rather than hearing the wrong narrator.

  404s for a meditation that does not exist, is archived, or has no
  narration in the voice asked for, so audio cannot outlive the content
  being withdrawn.
  """
  def audio(conn, %{"id" => id} = params) do
    voice = params["voice"]

    with {:ok, meditation} <- fetch_playable_meditation(id),
         {:ok, audio} <- fetch_audio(meditation, voice) do
      conn
      # A presigned URL is single-use in spirit and time-limited in fact.
      # Nothing between here and the device may keep a copy to hand to
      # somebody else after it has expired.
      |> put_resp_header("cache-control", "private, no-store")
      |> render(:audio, id: meditation.id, audio: audio)
    end
  end

  defp fetch_audio(meditation, voice) do
    case Rosary.fetch_meditation_audio(meditation, blank_to_nil(voice)) do
      {:ok, audio} -> {:ok, audio}
      {:error, :unknown_voice} -> {:error, {:bad_request, "Unknown voice: #{voice}"}}
      :error -> {:error, :not_found}
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp fetch_playable_meditation(id) do
    case Integer.parse(to_string(id)) do
      {meditation_id, ""} ->
        case Rosary.get_meditation(meditation_id) do
          nil ->
            {:error, :not_found}

          meditation ->
            if Rosary.meditation_archived?(meditation),
              do: {:error, :not_found},
              else: {:ok, meditation}
        end

      _ ->
        {:error, :not_found}
    end
  end
end
