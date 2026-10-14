defmodule LumenViae.Curation.ChantUploadTest do
  @moduledoc """
  `LumenViae.Curation.ChantUpload` against a folder of stand-in files and
  a stand-in bucket: what it uploads, what it skips, and what it writes.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Curation.ChantUpload
  alias LumenViae.Storage.S3

  # A bucket in the test process: it holds the keys in the process
  # dictionary, and reports each upload as a message.
  defmodule Bucket do
    def audio_exists?(key, _opts), do: {:ok, key in Process.get(:bucket, [])}

    def upload_public(binary, key, opts) do
      send(self(), {:uploaded, key, byte_size(binary), opts[:content_type]})
      Process.put(:bucket, [key | Process.get(:bucket, [])])
      {:ok, key}
    end
  end

  defmodule BrokenBucket do
    def audio_exists?(_key, _opts), do: {:ok, false}
    def upload_public(_binary, _key, _opts), do: {:error, :access_denied}
  end

  @now ~U[2026-10-14 12:00:00Z]

  setup do
    dir = Path.join(System.tmp_dir!(), "chant_upload_#{System.unique_integer([:positive])}")
    source = Path.join(dir, "Chants")
    library = Path.join(dir, "library")
    File.mkdir_p!(Path.join(source, "Scores"))
    File.mkdir_p!(library)
    on_exit(fn -> File.rm_rf!(dir) end)

    File.write!(Path.join(source, "salve_regina_simple.m4a"), "a recording")
    File.write!(Path.join(source, "sub_tuum.m4a"), "another recording")
    File.write!(Path.join(source, "Scores/chant-salve.lvscore"), "a score")
    File.write!(Path.join(source, "Scores/chant-ora.lvscore"), "a shared verse")

    File.write!(
      Path.join(library, "prayer_book.json"),
      Jason.encode!(%{"prayers" => [%{"id" => "hail_holy_queen"}]})
    )

    export = Path.join(dir, "export.json")
    File.write!(export, Jason.encode!(export_document()))

    %{source: source, document: Path.join(library, "chant_library.json"), export: export}
  end

  test "uploads every file once, by its checksum, and writes the URLs", context do
    assert {:ok, %{uploaded: uploaded, present: [], rewritten?: true}} = run(context)

    sha = sha("a recording")

    assert "chants/audio/salve_regina_simple-#{binary_part(sha, 0, 12)}.m4a" in uploaded
    # Two recordings and two score pages: the chants share the verse page,
    # and it is uploaded once.
    assert length(uploaded) == 4
    assert_received {:uploaded, "chants/audio/" <> _, 11, "audio/mp4"}
    assert_received {:uploaded, "chants/scores/chant-salve-" <> _, 7, "application/octet-stream"}

    written = context.document |> File.read!() |> Jason.decode!()

    assert written["updated_at"] == "2026-10-14T12:00:00Z"
    assert context.document |> File.read!() |> String.starts_with?("{\n  \"updated_at\"")

    [salve, other] = written["chants"]

    assert salve["audio"] == %{
             "url" =>
               S3.public_url("chants/audio/salve_regina_simple-#{binary_part(sha, 0, 12)}.m4a"),
             "bytes" => 11,
             "sha256" => sha
           }

    assert [%{"file" => "chant-salve", "bytes" => 7}, %{"file" => "chant-ora"}] = salve["score"]
    assert hd(other["score"])["url"] == List.last(salve["score"])["url"]

    # Everything but the files' places is the export's.
    assert Map.delete(salve, "audio") |> Map.delete("score") ==
             hd(export_document()["chants"]) |> Map.delete("audio") |> Map.delete("score")
  end

  test "a second run uploads nothing and leaves the file and its date alone", context do
    {:ok, _} = run(context)
    before = File.read!(context.document)

    assert {:ok, %{uploaded: [], present: present, rewritten?: false}} =
             run(context, now: ~U[2026-10-15 12:00:00Z])

    assert length(present) == 4
    assert File.read!(context.document) == before
  end

  test "a changed recording is a new key and a new date", context do
    {:ok, _} = run(context)
    File.write!(Path.join(context.source, "salve_regina_simple.m4a"), "a better recording")

    assert {:ok, %{uploaded: [key], rewritten?: true}} =
             run(context, from: context.document, now: ~U[2026-10-15 12:00:00Z])

    assert key =~ binary_part(sha("a better recording"), 0, 12)

    assert (context.document |> File.read!() |> Jason.decode!())["updated_at"] ==
             "2026-10-15T12:00:00Z"
  end

  test "a dry run asks the bucket nothing and writes nothing", context do
    assert {:ok, %{uploaded: uploaded, rewritten?: true}} =
             run(context, dry_run: true, storage: BrokenBucket)

    assert length(uploaded) == 4
    refute File.exists?(context.document)
  end

  test "a missing file stops the run before anything is uploaded", context do
    File.rm!(Path.join(context.source, "Scores/chant-ora.lvscore"))

    assert {:error, message} = run(context)
    assert message =~ "Scores/chant-ora.lvscore"
    refute_received {:uploaded, _, _, _}
    refute File.exists?(context.document)
  end

  test "a failed upload writes nothing", context do
    assert {:error, message} = run(context, storage: BrokenBucket)
    assert message =~ ":access_denied"
    refute File.exists?(context.document)
  end

  test "a chant id that would leave the folder is refused before a path is built", context do
    document = put_in(export_document(), ["chants", Access.at(0), "id"], "../salve")
    File.write!(context.export, Jason.encode!(document))

    assert {:error, message} = run(context)
    assert message =~ ~s("../salve")
    refute File.exists?(context.document)
  end

  test "a document that would not compile is refused", context do
    document = put_in(export_document(), ["chants", Access.at(0), "prayer_ids"], ["nowhere"])
    File.write!(context.export, Jason.encode!(document))

    assert {:error, message} = run(context)
    assert message =~ ~s(names the prayer "nowhere")
    refute File.exists?(context.document)
  end

  defp run(context, opts \\ []) do
    [
      source: context.source,
      file: context.document,
      from: context.export,
      storage: Bucket,
      now: @now
    ]
    |> Keyword.merge(opts)
    |> ChantUpload.run()
  end

  defp sha(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)

  defp export_document do
    %{
      "chants" => [
        chant("salve_regina_simple", [score("chant-salve"), score("chant-ora")]),
        chant("sub_tuum", [score("chant-ora")])
      ],
      "groups" => [
        %{
          "id" => "ourLady",
          "title" => "Our Lady",
          "note" => nil,
          "parts" => [
            %{"title" => nil, "note" => nil, "chant_ids" => ["salve_regina_simple", "sub_tuum"]}
          ]
        }
      ]
    }
  end

  defp chant(id, score) do
    %{
      "id" => id,
      "group_id" => "ourLady",
      "latin_title" => id,
      "english_title" => id,
      "setting" => nil,
      "detail" => "A chant",
      "prayer_ids" => ["hail_holy_queen"],
      "duration" => 100,
      "source_url" => "https://www.verbumgloriae.es/",
      "audio" => %{"url" => nil, "bytes" => 1, "sha256" => nil},
      "score" => score,
      "lines" => [
        %{"latin" => "Salve", "english" => "Hail", "start" => 0, "end" => 5, "part" => 0}
      ]
    }
  end

  defp score(file),
    do: %{
      "file" => file,
      "caption" => file,
      "aspect_ratio" => 2.0,
      "url" => nil,
      "bytes" => 1,
      "sha256" => nil
    }
end
