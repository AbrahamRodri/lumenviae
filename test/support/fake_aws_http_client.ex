defmodule LumenViae.Test.FakeAwsHttpClient do
  @moduledoc """
  ExAws HTTP client stub for tests that exercise S3 uploads.

  Enable it (with stub credentials so `ExAws.Config` validation passes) in a
  test's setup and register the test process to receive each request:

      Application.put_env(:ex_aws, :http_client, LumenViae.Test.FakeAwsHttpClient)
      Application.put_env(:ex_aws, :access_key_id, "test-key")
      Application.put_env(:ex_aws, :secret_access_key, "test-secret")
      Application.put_env(:lumen_viae, :fake_aws_test_pid, self())

  Every request is mirrored to the registered pid as
  `{:aws_request, method, url, body}`.

  By default every request succeeds with an empty 200, so every HEAD says
  the object exists. A test that needs a bucket that remembers - one where
  a HEAD on a key nobody wrote is a 404, and a HEAD on a key that was
  written answers with the metadata it was written with - calls `store!/0`
  in its setup.
  """

  @behaviour ExAws.Request.HttpClient

  @store :lumen_viae_fake_aws_store

  @doc """
  Turns on the remembering bucket for the current test, empty, and turns
  it off again when the test exits.
  """
  def store! do
    if :ets.whereis(@store) == :undefined do
      :ets.new(@store, [:named_table, :public, :set])
    else
      :ets.delete_all_objects(@store)
    end

    Application.put_env(:lumen_viae, :fake_aws_store, true)
    ExUnit.Callbacks.on_exit(fn -> Application.delete_env(:lumen_viae, :fake_aws_store) end)
    :ok
  end

  @doc "Puts an object straight into the remembering bucket, as if uploaded earlier."
  def put_object!(key, meta \\ %{}) do
    :ets.insert(@store, {key, meta})
    :ok
  end

  @impl true
  def request(method, url, body, headers, _http_opts) do
    case Application.get_env(:lumen_viae, :fake_aws_test_pid) do
      pid when is_pid(pid) -> send(pid, {:aws_request, method, url, body})
      _ -> :ok
    end

    if Application.get_env(:lumen_viae, :fake_aws_store),
      do: remembered(method, key_of(url), headers),
      else: {:ok, %{status_code: 200, headers: [], body: ""}}
  end

  # :fake_aws_refuse_puts makes every upload a 403, which ExAws does not
  # retry, for testing what happens to audio that cannot be stored.
  defp remembered(:put, key, headers) do
    if Application.get_env(:lumen_viae, :fake_aws_refuse_puts),
      do: {:ok, %{status_code: 403, headers: [], body: "AccessDenied"}},
      else: store_put(key, headers)
  end

  defp remembered(:head, key, headers), do: head(key, headers)
  defp remembered(_method, _key, _headers), do: {:ok, %{status_code: 200, headers: [], body: ""}}

  defp store_put(key, headers) do
    meta =
      for {name, value} <- headers,
          name = String.downcase(name),
          String.starts_with?(name, "x-amz-meta-"),
          into: %{},
          do: {String.replace_prefix(name, "x-amz-meta-", ""), value}

    :ets.insert(@store, {key, meta})
    {:ok, %{status_code: 200, headers: [], body: ""}}
  end

  defp head(key, _headers) do
    case :ets.lookup(@store, key) do
      [{^key, meta}] ->
        {:ok,
         %{
           status_code: 200,
           headers: Enum.map(meta, fn {k, v} -> {"x-amz-meta-" <> k, v} end),
           body: ""
         }}

      [] ->
        {:ok, %{status_code: 404, headers: [], body: ""}}
    end
  end

  # The object key: the URL path without the bucket's own segment.
  defp key_of(url) do
    case url |> URI.parse() |> Map.get(:path) |> String.split("/", parts: 3) do
      ["", _bucket, key] -> URI.decode(key)
      _ -> url
    end
  end
end
