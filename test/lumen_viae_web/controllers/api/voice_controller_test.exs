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

  # V1: types only, so it survives a change of voices. `default` is a
  # non-optional Bool on the device and null fails the whole list.
  test "every voice is correctly typed and exactly the first is the default", %{conn: conn} do
    data = conn |> get(~p"/api/voices") |> json_response(200) |> Map.fetch!("data")

    assert data != []

    for voice <- data do
      assert is_binary(voice["slug"])
      assert is_binary(voice["name"])
      assert is_boolean(voice["default"])
      assert_string_or_nil(voice["description"], "description")
    end

    assert Enum.count(data, & &1["default"]) == 1
    assert hd(data)["default"] == true
  end

  # G2: URLSession's default Accept.
  test "answers */* with 200 JSON", %{conn: conn} do
    assert conn
           |> Plug.Conn.put_req_header("accept", "*/*")
           |> get(~p"/api/voices")
           |> json_response(200)
  end
end
