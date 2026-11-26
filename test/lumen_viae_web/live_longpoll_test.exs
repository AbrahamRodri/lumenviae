defmodule LumenViaeWeb.LiveLongpollTest do
  @moduledoc """
  The long-poll fallback app.js asks for when the websocket does not
  connect (`longPollFallbackMs`): it must exist, or a page whose websocket
  fails stays disconnected behind a 404.
  """
  use LumenViaeWeb.ConnCase, async: true

  test "the long-poll transport answers at /live/longpoll", %{conn: conn} do
    conn = get(conn, "/live/longpoll?vsn=2.0.0")

    refute conn.status == 404
    assert %{"status" => _} = Jason.decode!(conn.resp_body)
  end
end
