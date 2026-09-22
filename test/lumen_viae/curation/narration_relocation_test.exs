defmodule LumenViae.Curation.NarrationRelocationTest do
  use LumenViae.DataCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViae.Curation.NarrationRelocation
  alias LumenViae.Rosary

  defmodule HeadThenCopyClient do
    @moduledoc "HEAD answers from a per-key map; every other request succeeds."
    @behaviour ExAws.Request.HttpClient

    @impl true
    def request(method, url, body, _headers, _opts) do
      pid = Application.get_env(:lumen_viae, :fake_aws_test_pid)
      send(pid, {:aws_request, method, url, body})

      case method do
        :head ->
          exists = Application.get_env(:lumen_viae, :relocation_existing, [])

          if Enum.any?(exists, &String.ends_with?(URI.parse(url).path, &1)),
            do: {:ok, %{status_code: 200, headers: [], body: ""}},
            else: {:ok, %{status_code: 404, headers: [], body: ""}}

        :put ->
          missing = Application.get_env(:lumen_viae, :relocation_missing_sources, [])

          if Enum.any?(missing, &String.contains?(url, &1)),
            do:
              {:ok,
               %{status_code: 404, headers: [], body: "<Error><Code>NoSuchKey</Code></Error>"}},
            else: {:ok, %{status_code: 200, headers: [], body: "<CopyObjectResult/>"}}
      end
    end
  end

  setup do
    put_env(:ex_aws, :http_client, HeadThenCopyClient)
    put_env(:ex_aws, :access_key_id, "test-key")
    put_env(:ex_aws, :secret_access_key, "test-secret")
    put_env(:lumen_viae, :fake_aws_test_pid, self())
    put_env(:lumen_viae, :relocation_existing, [])
    put_env(:lumen_viae, :relocation_missing_sources, [])

    {:ok, mystery} =
      Rosary.create_mystery(%{name: "The Annunciation", category: "joyful", order: 1})

    {:ok, a} =
      Rosary.create_meditation(%{content: "A", mystery_id: mystery.id, audio_url: "a.mp3"})

    {:ok, b} =
      Rosary.create_meditation(%{content: "B", mystery_id: mystery.id, audio_url: "b.mp3"})

    {:ok, _} = Rosary.create_meditation(%{content: "C", mystery_id: mystery.id})

    %{a: a, b: b}
  end

  test "copies each original to voices/male/ and skips what is already there", %{a: a, b: b} do
    put_env(:lumen_viae, :relocation_existing, ["voices/male/b.mp3"])

    results = NarrationRelocation.run()

    assert [{:ok, copied}, {:ok, kept}] = results
    assert copied =~ "Copied a.mp3 to voices/male/a.mp3 for meditation #{a.id}"
    assert kept =~ "Kept voices/male/b.mp3 for meditation #{b.id}"

    assert_received {:aws_request, :put, url, _}
    assert URI.parse(url).path == "/lumenviae-audio/voices/male/a.mp3"
    refute_received {:aws_request, :put, _, _}
  end

  test "a missing original is a warning, not a failure", %{a: a} do
    put_env(:lumen_viae, :relocation_missing_sources, ["a.mp3"])

    assert [{:warning, warning}, {:ok, _}] = NarrationRelocation.run()
    assert warning =~ "No object at a.mp3 for meditation #{a.id}"
  end
end
