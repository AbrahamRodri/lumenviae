defmodule LumenViae.Storage.CopyTest do
  use ExUnit.Case, async: true

  alias LumenViae.Storage.Copy
  alias Mix.Tasks.LumenViae.CopyStorage

  # A bucket in an Agent: key => %{body, content_type, cache_control}.
  # `:etag` says what a put reports back: `:md5` like S3 and R2, or
  # `:wrong` like a store that mangled the bytes.
  defmodule MemoryStore do
    @behaviour LumenViae.Storage.Copy.Store

    def start(objects, opts \\ []) do
      ExUnit.Callbacks.start_supervised!(
        {Agent, fn -> %{objects: objects, puts: [], opts: opts} end},
        id: make_ref()
      )
    end

    def objects(pid), do: Agent.get(pid, & &1.objects)
    def puts(pid), do: Agent.get(pid, &Enum.reverse(&1.puts))

    @impl true
    # `multipart: true` lists ETags the way S3 does for a multipart upload,
    # which are not the MD5 of the bytes.
    def list(pid, prefix) do
      %{objects: objects, opts: opts} = Agent.get(pid, & &1)
      suffix = if opts[:multipart], do: "-2", else: ""

      objects
      |> Enum.filter(fn {key, _} -> String.starts_with?(key, prefix) end)
      |> Enum.sort()
      |> Enum.map(fn {key, object} ->
        %{key: key, size: byte_size(object.body), etag: ~s("#{md5(object.body)}#{suffix}")}
      end)
    end

    @impl true
    def head(pid, key) do
      %{objects: objects, opts: opts} = Agent.get(pid, & &1)

      case Map.fetch(objects, key) do
        {:ok, object} -> {:ok, meta(object, opts)}
        :error -> :missing
      end
    end

    @impl true
    def get(pid, key) do
      %{objects: objects, opts: opts} = Agent.get(pid, & &1)
      object = Map.fetch!(objects, key)
      {:ok, object.body, meta(object, opts)}
    end

    @impl true
    def put(pid, key, body, meta) do
      if Keyword.get(Agent.get(pid, & &1.opts), :fail_put), do: raise("connection reset")

      object = %{body: body, content_type: meta.content_type, cache_control: meta.cache_control}

      Agent.update(pid, fn state ->
        %{state | objects: Map.put(state.objects, key, object), puts: [key | state.puts]}
      end)
    end

    defp meta(object, opts) do
      etag = if opts[:etag] == :wrong, do: "\"0000\"", else: "\"#{md5(object.body)}\""

      %{
        size: byte_size(object.body),
        etag: etag,
        content_type: object.content_type,
        cache_control: object.cache_control
      }
    end

    defp md5(body), do: :crypto.hash(:md5, body) |> Base.encode16(case: :lower)
  end

  defp object(body, content_type \\ "audio/mpeg"),
    do: %{body: body, content_type: content_type, cache_control: "public, max-age=31536000"}

  setup do
    source =
      MemoryStore.start(%{
        "voices/frederick/a.mp3" => object("aaaa"),
        "voices/frederick/b.mp3" => object("bbbbbb"),
        "voices/arabella/c.mp3" => object("cc"),
        "images/x.jpg" => object("xxx", "image/jpeg")
      })

    %{source: source}
  end

  describe "a dry run" do
    test "counts what is missing and copies nothing", %{source: source} do
      destination = MemoryStore.start(%{"voices/frederick/a.mp3" => object("aaaa")})

      result = Copy.run({MemoryStore, source}, {MemoryStore, destination}, dry_run: true)

      assert result.present == 1
      assert result.to_copy == 3
      assert result.to_copy_bytes == 6 + 2 + 3
      assert result.copied == 0
      assert MemoryStore.puts(destination) == []
    end
  end

  describe "a run" do
    test "copies what is missing or a different size, and skips what is there", %{source: source} do
      destination =
        MemoryStore.start(%{
          "voices/frederick/a.mp3" => object("aaaa"),
          "voices/frederick/b.mp3" => object("bb")
        })

      result = Copy.run({MemoryStore, source}, {MemoryStore, destination})

      assert result.present == 1
      assert result.copied == 3
      assert result.copied_bytes == 6 + 2 + 3
      assert result.failed == []

      assert MemoryStore.puts(destination) ==
               ["images/x.jpg", "voices/arabella/c.mp3", "voices/frederick/b.mp3"]

      assert MemoryStore.objects(destination)["voices/frederick/b.mp3"].body == "bbbbbb"
    end

    test "keeps each object's content type and cache control", %{source: source} do
      destination = MemoryStore.start(%{})

      Copy.run({MemoryStore, source}, {MemoryStore, destination})

      copy = MemoryStore.objects(destination)["images/x.jpg"]
      assert copy.content_type == "image/jpeg"
      assert copy.cache_control == "public, max-age=31536000"
    end

    test "copies only the prefix", %{source: source} do
      destination = MemoryStore.start(%{})

      result =
        Copy.run({MemoryStore, source}, {MemoryStore, destination}, prefix: "voices/frederick/")

      assert result.copied == 2

      assert Map.keys(MemoryStore.objects(destination)) |> Enum.sort() ==
               ["voices/frederick/a.mp3", "voices/frederick/b.mp3"]
    end

    test "never deletes: an object only the destination has stays", %{source: source} do
      destination = MemoryStore.start(%{"voices/old.mp3" => object("old")})

      Copy.run({MemoryStore, source}, {MemoryStore, destination})

      assert MemoryStore.objects(destination)["voices/old.mp3"].body == "old"
      assert map_size(MemoryStore.objects(source)) == 4
    end

    test "copies an object of the same size whose bytes differ", %{source: source} do
      destination = MemoryStore.start(%{"voices/frederick/a.mp3" => object("zzzz")})

      result =
        Copy.run({MemoryStore, source}, {MemoryStore, destination}, prefix: "voices/frederick/a")

      assert result.present == 0
      assert result.copied == 1
      assert MemoryStore.objects(destination)["voices/frederick/a.mp3"].body == "aaaa"
    end

    test "against a multipart ETag, which is no MD5, the size alone decides" do
      source = MemoryStore.start(%{"voices/big.mp3" => object("aaaa")}, multipart: true)
      destination = MemoryStore.start(%{"voices/big.mp3" => object("zzzz")})

      result = Copy.run({MemoryStore, source}, {MemoryStore, destination})

      assert result.present == 1
      assert MemoryStore.puts(destination) == []
    end

    test "a second run copies nothing", %{source: source} do
      destination = MemoryStore.start(%{})

      Copy.run({MemoryStore, source}, {MemoryStore, destination})
      again = Copy.run({MemoryStore, source}, {MemoryStore, destination})

      assert again.present == 4
      assert again.copied == 0
    end

    test "reports a copy whose ETag is not the MD5 of the bytes sent", %{source: source} do
      destination = MemoryStore.start(%{}, etag: :wrong)

      result = Copy.run({MemoryStore, source}, {MemoryStore, destination}, prefix: "images/")

      assert result.copied == 0
      assert [{"images/x.jpg", why}] = result.failed
      assert why =~ "ETag"
    end

    test "reports a failed upload and carries on", %{source: source} do
      destination = MemoryStore.start(%{}, fail_put: true)

      result = Copy.run({MemoryStore, source}, {MemoryStore, destination})

      assert length(result.failed) == 4
      assert {"images/x.jpg", "connection reset"} in result.failed
    end

    test "calls on_object for every object", %{source: source} do
      destination = MemoryStore.start(%{"images/x.jpg" => object("xxx", "image/jpeg")})
      test = self()

      Copy.run({MemoryStore, source}, {MemoryStore, destination},
        on_object: fn event -> send(test, event) end
      )

      assert_received {:present, "images/x.jpg", 3}
      assert_received {:copied, "voices/arabella/c.mp3", 2}
    end
  end

  describe "the mix task" do
    test "points the destination at the account's R2 host with region auto" do
      config =
        CopyStorage.r2_config(%{
          "R2_ACCOUNT_ID" => "abc123",
          "R2_ACCESS_KEY_ID" => "key",
          "R2_SECRET_ACCESS_KEY" => "secret"
        })

      assert config[:host] == "abc123.r2.cloudflarestorage.com"
      assert config[:region] == "auto"
      assert config[:access_key_id] == "key"
    end

    test "refuses to run without the R2 keys" do
      assert_raise Mix.Error, ~r/R2_ACCOUNT_ID/, fn -> CopyStorage.r2_config(%{}) end
    end

    test "refuses a run that does not say --from s3 --to r2" do
      assert_raise Mix.Error, ~r/--from s3 --to r2/, fn -> CopyStorage.run(["--dry-run"]) end

      assert_raise Mix.Error, ~r/--from s3 --to r2/, fn ->
        CopyStorage.run(["--from", "r2", "--to", "s3"])
      end
    end
  end
end
