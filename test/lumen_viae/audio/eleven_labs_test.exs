defmodule LumenViae.Audio.ElevenLabsTest do
  use ExUnit.Case, async: false

  alias LumenViae.Audio.ElevenLabs

  setup do
    original_key = Application.get_env(:lumen_viae, :eleven_labs_api_key)
    original_req = Application.get_env(:lumen_viae, :eleven_labs_req_options)

    Application.put_env(:lumen_viae, :eleven_labs_api_key, "test-api-key")

    Application.put_env(:lumen_viae, :eleven_labs_req_options,
      plug: {Req.Test, LumenViae.Audio.ElevenLabs}
    )

    on_exit(fn ->
      restore_env(:eleven_labs_api_key, original_key)
      restore_env(:eleven_labs_req_options, original_req)
    end)

    :ok
  end

  defp restore_env(key, nil), do: Application.delete_env(:lumen_viae, key)
  defp restore_env(key, value), do: Application.put_env(:lumen_viae, key, value)

  test "returns audio binary on success" do
    Req.Test.stub(ElevenLabs, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("audio/mpeg")
      |> Plug.Conn.send_resp(200, <<1, 2, 3, 4>>)
    end)

    assert {:ok, <<1, 2, 3, 4>>} = ElevenLabs.generate_audio("Hail Mary, full of grace")
  end

  test "an empty 200 response is a retryable error" do
    Req.Test.stub(ElevenLabs, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("audio/mpeg")
      |> Plug.Conn.send_resp(200, "")
    end)

    assert {:error, message} = ElevenLabs.generate_audio("text")
    assert message =~ "empty audio response"
  end

  test "a rejected API key is a fatal error" do
    Req.Test.stub(ElevenLabs, fn conn ->
      conn
      |> Plug.Conn.put_status(401)
      |> Req.Test.json(%{
        "detail" => %{"status" => "invalid_api_key", "message" => "Invalid API key"}
      })
    end)

    assert {:error, {:fatal, message}} = ElevenLabs.generate_audio("text")
    assert message =~ "rejected the API key"
    assert message =~ "Invalid API key"
  end

  test "a rate limit is a retryable error" do
    Req.Test.stub(ElevenLabs, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(%{"detail" => "too many requests"})
    end)

    assert {:error, message} = ElevenLabs.generate_audio("text")
    assert message =~ "throttled"
    refute match?({:fatal, _}, message)
  end

  test "an invalid request is a fatal error" do
    Req.Test.stub(ElevenLabs, fn conn ->
      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{"detail" => "text too long"})
    end)

    assert {:error, {:fatal, message}} = ElevenLabs.generate_audio("text")
    assert message =~ "rejected the request"
  end

  test "a server error is a retryable error" do
    Req.Test.stub(ElevenLabs, fn conn ->
      conn
      |> Plug.Conn.put_status(500)
      |> Req.Test.json(%{"detail" => "internal error"})
    end)

    assert {:error, message} = ElevenLabs.generate_audio("text")
    assert message =~ "server error (status 500)"
  end

  test "a timeout reports the configured receive timeout instead of a connect failure" do
    Req.Test.stub(ElevenLabs, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, message} = ElevenLabs.generate_audio("text")
    assert message =~ "did not respond within 120s"
  end

  test "a missing API key is fatal and makes no request" do
    Application.put_env(:lumen_viae, :eleven_labs_api_key, nil)

    assert {:error, {:fatal, message}} = ElevenLabs.generate_audio("text")
    assert message =~ "API key not configured"
  end

  test "a missing voice ID is fatal and makes no request" do
    original_voices = Application.get_env(:lumen_viae, :narration_voices)
    Application.put_env(:lumen_viae, :narration_voices, [])
    on_exit(fn -> restore_env(:narration_voices, original_voices) end)

    assert {:error, {:fatal, message}} = ElevenLabs.generate_audio("text")
    assert message =~ "voice ID not configured"
  end

  test "synthesizes with the configured model and the voice it is given" do
    test_pid = self()

    Req.Test.stub(ElevenLabs, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:request, conn.request_path, Jason.decode!(body)})

      conn
      |> Plug.Conn.put_resp_content_type("audio/mpeg")
      |> Plug.Conn.send_resp(200, "bytes")
    end)

    assert {:ok, "bytes"} = ElevenLabs.generate_audio("text", "voice-123")

    assert_received {:request, "/v1/text-to-speech/voice-123", body}
    assert body["model_id"] == "eleven_v3"
    assert body["voice_settings"] == %{"stability" => 0.5, "similarity_boost" => 0.75}

    assert {:ok, "bytes"} =
             ElevenLabs.generate_audio("text", "voice-456",
               model_id: "eleven_multilingual_v2",
               voice_settings: %{style: 0.5}
             )

    assert_received {:request, "/v1/text-to-speech/voice-456", body}
    assert body["model_id"] == "eleven_multilingual_v2"

    assert body["voice_settings"] ==
             %{"stability" => 0.5, "similarity_boost" => 0.75, "style" => 0.5}
  end

  test "the pause style follows the model" do
    assert ElevenLabs.pause_style("eleven_v3") == :audio_tags
    assert ElevenLabs.pause_style("eleven_multilingual_v2") == :break_tags
  end
end
