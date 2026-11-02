defmodule LumenViae.Storage.Copy do
  @moduledoc """
  Copies a bucket's objects from one S3-compatible store to another (AWS S3
  to Cloudflare R2, for `mix lumen_viae.copy_storage`), and never deletes.

  For each source object it copies only what the destination is missing, or
  holds with a different size or MD5, keeping the object's content type and cache
  control, and then reads the copy back: the size must match and the
  destination's ETag must be the MD5 of the bytes sent. A copy that fails
  that check is reported, not retried, and the run goes on. With `dry_run:
  true` it reads both listings and copies nothing.

  The stores are `{module, state}` pairs implementing
  `LumenViae.Storage.Copy.Store`, so the logic is tested against an
  in-memory store; `LumenViae.Storage.Copy.S3Store` is the real one.
  """

  defmodule Store do
    @moduledoc "One side of a copy: an S3-compatible bucket, or a stand-in."

    @type object :: %{key: String.t(), size: non_neg_integer(), etag: String.t()}
    @type meta :: %{
            size: non_neg_integer(),
            etag: String.t(),
            content_type: String.t() | nil,
            cache_control: String.t() | nil
          }

    @callback list(state :: term(), prefix :: String.t()) :: Enumerable.t(object())
    @callback head(state :: term(), key :: String.t()) :: {:ok, meta()} | :missing
    @callback get(state :: term(), key :: String.t()) :: {:ok, binary(), meta()}
    @callback put(state :: term(), key :: String.t(), body :: binary(), meta()) :: :ok
  end

  @type store :: {module(), term()}
  @type result :: %{
          copied: non_neg_integer(),
          copied_bytes: non_neg_integer(),
          present: non_neg_integer(),
          to_copy: non_neg_integer(),
          to_copy_bytes: non_neg_integer(),
          failed: [{String.t(), String.t()}]
        }

  @doc """
  Copies `prefix` from `source` to `destination`. `on_object` is called
  with `{status, key, size}` for every object (`:present`, `:to_copy`,
  `:copied` or `{:failed, why}`), for progress lines.
  """
  @spec run(store(), store(), keyword()) :: result()
  def run({src, src_state}, {dst, dst_state}, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "")
    dry_run = Keyword.get(opts, :dry_run, false)
    report = Keyword.get(opts, :on_object, fn _ -> :ok end)

    acc = %{copied: 0, copied_bytes: 0, present: 0, to_copy: 0, to_copy_bytes: 0, failed: []}

    src.list(src_state, prefix)
    |> Enum.reduce(acc, fn %{key: key, size: size} = object, acc ->
      cond do
        present?(dst.head(dst_state, key), object) ->
          report.({:present, key, size})
          %{acc | present: acc.present + 1}

        dry_run ->
          report.({:to_copy, key, size})
          %{acc | to_copy: acc.to_copy + 1, to_copy_bytes: acc.to_copy_bytes + size}

        true ->
          acc = %{acc | to_copy: acc.to_copy + 1, to_copy_bytes: acc.to_copy_bytes + size}
          outcome = copy_one({src, src_state}, {dst, dst_state}, key)
          count(outcome, key, size, acc, report)
      end
    end)
  end

  defp count(:ok, key, size, acc, report) do
    report.({:copied, key, size})
    %{acc | copied: acc.copied + 1, copied_bytes: acc.copied_bytes + size}
  end

  defp count({:error, why}, key, size, acc, report) do
    report.({{:failed, why}, key, size})
    %{acc | failed: acc.failed ++ [{key, why}]}
  end

  # The same size, and the same bytes when both ETags are plain MD5s. A
  # multipart upload's ETag ("<md5>-<parts>") is not the MD5 of the bytes,
  # so for one of those the size is all that can be compared.
  defp present?({:ok, %{size: size, etag: copy}}, %{size: size, etag: original}) do
    copy = unquote_etag(copy)
    original = unquote_etag(original)
    not (md5?(copy) and md5?(original)) or copy == original
  end

  defp present?(_head, _object), do: false

  defp md5?(etag), do: etag =~ ~r/\A[0-9a-f]{32}\z/

  defp copy_one({src, src_state}, {dst, dst_state}, key) do
    {:ok, body, meta} = src.get(src_state, key)
    md5 = :crypto.hash(:md5, body) |> Base.encode16(case: :lower)

    :ok = dst.put(dst_state, key, body, meta)

    case dst.head(dst_state, key) do
      {:ok, %{size: size, etag: etag}} when size == byte_size(body) ->
        if unquote_etag(etag) == md5,
          do: :ok,
          else: {:error, "MD5 #{md5} but the copy's ETag is #{etag}"}

      {:ok, %{size: size}} ->
        {:error, "sent #{byte_size(body)} bytes but the copy has #{size}"}

      :missing ->
        {:error, "the copy is not there after the upload"}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp unquote_etag(etag), do: etag |> String.trim("\"") |> String.downcase()
end
