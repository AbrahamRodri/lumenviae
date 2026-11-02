defmodule LumenViae.Storage.Copy.S3Store do
  @moduledoc """
  An S3-compatible bucket as one side of `LumenViae.Storage.Copy`: AWS S3
  with the app's own `ex_aws` settings, or any other endpoint (Cloudflare R2)
  given as overrides. The state is `{bucket, ex_aws_config_overrides}`.
  """
  @behaviour LumenViae.Storage.Copy.Store

  @impl true
  def list({bucket, overrides}, prefix) do
    ExAws.S3.list_objects_v2(bucket, prefix: prefix)
    |> ExAws.stream!(overrides)
    |> Stream.map(fn object ->
      %{key: object.key, size: String.to_integer(object.size), etag: object.e_tag}
    end)
  end

  @impl true
  def head({bucket, overrides}, key) do
    case ExAws.S3.head_object(bucket, key) |> ExAws.request(overrides) do
      {:ok, %{headers: headers}} -> {:ok, meta(headers)}
      {:error, {:http_error, 404, _}} -> :missing
      {:error, error} -> raise "HEAD #{bucket}/#{key} failed: #{inspect(error)}"
    end
  end

  @impl true
  def get({bucket, overrides}, key) do
    %{body: body, headers: headers} =
      ExAws.S3.get_object(bucket, key) |> ExAws.request!(overrides)

    {:ok, body, meta(headers)}
  end

  @impl true
  def put({bucket, overrides}, key, body, meta) do
    opts =
      [content_type: meta.content_type, cache_control: meta.cache_control]
      |> Enum.reject(fn {_, value} -> is_nil(value) end)

    ExAws.S3.put_object(bucket, key, body, opts) |> ExAws.request!(overrides)
    :ok
  end

  defp meta(headers) do
    named = Map.new(headers, fn {name, value} -> {String.downcase(name), value} end)
    one = fn name -> named |> Map.get(name) |> List.wrap() |> List.first() end

    %{
      size: String.to_integer(one.("content-length") || "0"),
      etag: one.("etag") || "",
      content_type: one.("content-type"),
      cache_control: one.("cache-control")
    }
  end
end
