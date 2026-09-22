defmodule LumenViaeWeb.API.VoiceController do
  @moduledoc """
  The narration voices, so a client can offer a picker without a list of
  its own that would drift from the server's.
  """
  use LumenViaeWeb, :controller

  alias LumenViae.Rosary

  action_fallback LumenViaeWeb.API.FallbackController

  @doc """
  Lists every narration voice, default first. Voices are configuration and
  change only with a deploy, so the response may be cached for a while.
  """
  def index(conn, _params) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> render(:index, voices: Rosary.list_voices())
  end
end
