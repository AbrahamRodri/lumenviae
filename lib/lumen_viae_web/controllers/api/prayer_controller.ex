defmodule LumenViaeWeb.API.PrayerController do
  @moduledoc """
  The consecration chants, withdrawn.

  This endpoint used to sign one of four fixed S3 keys (Veni Creator, Ave
  Maris Stella, the Magnificat and a Gloria Patri) for the iOS app to play.
  The three chants had no licence (the Magnificat was a YouTube download)
  and nobody knows where the Gloria Patri came from, so all four were
  withdrawn. The app bundles licensed chants of its own from its next
  version on, and that version never calls this endpoint.

  The route stays because installed builds still call it. Every id answers
  410 `gone` and nothing is signed: those builds already treat any error
  from here as "the chant couldn't be loaded" and leave the prayer to be
  read. Links issued before the withdrawal expire on their own within
  `LumenViae.Rosary.audio_url_ttl/0`. The objects are left in the bucket;
  do not reintroduce a key here.
  """
  use LumenViaeWeb, :controller

  action_fallback LumenViaeWeb.API.FallbackController

  @doc """
  Answers 410 for every prayer, including the four that were once signed.
  """
  def audio(_conn, %{"id" => _id}), do: {:error, :gone}
end
