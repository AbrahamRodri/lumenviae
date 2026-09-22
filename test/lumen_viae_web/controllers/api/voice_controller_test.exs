defmodule LumenViaeWeb.API.VoiceControllerTest do
  use LumenViaeWeb.ConnCase, async: true

  test "GET /api/voices lists the voices, default first", %{conn: conn} do
    conn = get(conn, ~p"/api/voices")
    data = conn |> json_response(200) |> Map.fetch!("data")

    assert [
             %{"slug" => "female", "name" => "Female", "default" => true},
             %{"slug" => "male", "name" => "Male", "default" => false}
           ] = data

    assert Enum.all?(data, &is_binary(&1["description"]))
    assert get_resp_header(conn, "cache-control") == ["public, max-age=3600"]
  end
end
