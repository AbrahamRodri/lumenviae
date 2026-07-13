defmodule LumenViae.Test.FakeAwsHttpClient do
  @moduledoc """
  ExAws HTTP client stub for tests that exercise S3 uploads.

  Enable it (with stub credentials so `ExAws.Config` validation passes) in a
  test's setup and register the test process to receive each request:

      Application.put_env(:ex_aws, :http_client, LumenViae.Test.FakeAwsHttpClient)
      Application.put_env(:ex_aws, :access_key_id, "test-key")
      Application.put_env(:ex_aws, :secret_access_key, "test-secret")
      Application.put_env(:lumen_viae, :fake_aws_test_pid, self())

  Every request succeeds with an empty 200 response and is mirrored to the
  registered pid as `{:aws_request, method, url, body}`.
  """

  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(method, url, body, _headers, _http_opts) do
    case Application.get_env(:lumen_viae, :fake_aws_test_pid) do
      pid when is_pid(pid) -> send(pid, {:aws_request, method, url, body})
      _ -> :ok
    end

    {:ok, %{status_code: 200, headers: [], body: ""}}
  end
end
