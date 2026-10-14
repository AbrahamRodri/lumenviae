defmodule LumenViae.Curation.ChantUpload do
  @moduledoc """
  Puts every chant recording and score page in the public assets bucket
  and writes where each one is into `priv/library/chant_library.json`.

  The iOS app's export (`Tools/ContentExport`) leaves each file's URL
  null: this is what fills it, reading the export (`:from`) and writing
  the file the server compiles, which never holds a null URL.

  The files are the iOS app's, exactly as it bundled them:
  `<source>/<chant id>.m4a` and `<source>/Scores/<file>.lvscore`. Each is
  stored at a key named by its checksum,
  `chants/audio/<id>-<sha256 first 12>.m4a` and
  `chants/scores/<file>-<sha256 first 12>.lvscore`, with a year's
  immutable Cache-Control, so a changed file is a new URL and nothing
  already stored is ever overwritten. A key already in the bucket is not
  uploaded again, so a run is safe to repeat.

  Every chant's `audio` and score page then gets its `url`, `bytes` and
  `sha256`. When the result differs from the file already there, its
  `updated_at` moves to now,
  which moves the document's version; the file is checked
  (`LumenViae.Rosary.Library.chant_library_errors/2`) before it is written, and nothing
  is written when a file is missing or an upload fails.

  Run by `mix lumen_viae.upload_chants`.
  """

  alias LumenViae.Rosary.Library
  alias LumenViae.Storage.S3

  @audio_type "audio/mp4"
  @score_type "application/octet-stream"

  @type result :: %{
          uploaded: [String.t()],
          present: [String.t()],
          rewritten?: boolean,
          document: Jason.OrderedObject.t()
        }

  @doc """
  Uploads what is missing and writes the document.

  ## Options

    * `:source` - the folder holding the recordings, with the scores in
      its `Scores/` (required)
    * `:file` - the document to write (default
      `priv/library/chant_library.json`)
    * `:from` - the document to read, such as the iOS app's export with
      its URLs still null (default `:file` itself)
    * `:dry_run` - upload and write nothing; report what a run would do
    * `:storage` - the module that answers `audio_exists?/2` and
      `upload_public/3` (default `LumenViae.Storage.S3`)
    * `:now` - the time a changed document is dated (default now)

  The chants' `prayer_ids` are checked against `prayer_book.json` beside
  `:file`, read from disk rather than from the compiled
  `LumenViae.Rosary.Library`, so the task runs while a new export is
  still on its way in.
  """
  @spec run(keyword) :: {:ok, result} | {:error, String.t()}
  def run(opts) do
    source = Keyword.fetch!(opts, :source)
    file = Keyword.get(opts, :file, Path.join(File.cwd!(), "priv/library/chant_library.json"))
    from = Keyword.get(opts, :from, file)
    storage = Keyword.get(opts, :storage, S3)

    incoming = read(from)
    current = if File.exists?(file), do: read(file)
    prayer_ids = prayer_ids(Path.join(Path.dirname(file), "prayer_book.json"))

    with :ok <- named(incoming),
         {:ok, document, files} <- place(incoming, source),
         :ok <- check(document, prayer_ids),
         {:ok, uploaded, present} <- store(files, storage, opts[:dry_run]) do
      rewritten? = is_nil(current) or plain(document) != plain(current)

      document =
        if rewritten?,
          do: dated(document, stamp(opts[:now])),
          else: current

      if rewritten? and !opts[:dry_run], do: File.write!(file, encode(document))

      {:ok, %{uploaded: uploaded, present: present, rewritten?: rewritten?, document: document}}
    end
  end

  @doc """
  The bucket key a chant file is stored at: its folder, its name and the
  first twelve characters of its checksum.
  """
  @spec key(:audio | :score, String.t(), String.t()) :: String.t()
  def key(:audio, id, sha256), do: "chants/audio/#{id}-#{binary_part(sha256, 0, 12)}.m4a"
  def key(:score, file, sha256), do: "chants/scores/#{file}-#{binary_part(sha256, 0, 12)}.lvscore"

  # Every chant's audio and score pages, read from `source`, with the
  # document pointing at where each is stored.
  defp place(document, source) do
    {chants, files} =
      Enum.map_reduce(document["chants"], %{}, fn chant, files ->
        audio = local(source, "#{chant["id"]}.m4a", :audio, chant["id"], @audio_type)

        scores =
          Enum.map(chant["score"], fn part ->
            local(source, "Scores/#{part["file"]}.lvscore", :score, part["file"], @score_type)
          end)

        chant =
          chant
          |> put_file("audio", audio)
          |> update_in(["score"], fn parts ->
            parts |> Enum.zip(scores) |> Enum.map(fn {part, score} -> point(part, score) end)
          end)

        found = Enum.reject([audio | scores], &match?({:missing, _}, &1))
        {chant, Enum.reduce(found, files, &Map.put(&2, &1.key, &1))}
      end)

    case missing(chants, source) do
      [] -> {:ok, put_in(document["chants"], chants), Map.values(files)}
      paths -> {:error, "missing in #{source}: #{Enum.join(paths, ", ")}"}
    end
  end

  defp local(source, name, kind, stem, content_type) do
    path = Path.join(source, name)

    case File.read(path) do
      {:ok, bytes} ->
        sha256 = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
        key = key(kind, stem, sha256)

        %{
          path: path,
          key: key,
          url: S3.public_url(key),
          bytes: byte_size(bytes),
          sha256: sha256,
          content_type: content_type
        }

      {:error, _reason} ->
        {:missing, name}
    end
  end

  defp put_file(chant, _field, {:missing, _name}), do: chant

  defp put_file(chant, field, file) do
    existing = chant[field] || Jason.OrderedObject.new([])
    put_in(chant[field], point(existing, file))
  end

  defp point(object, {:missing, _name}), do: object

  defp point(object, file) do
    object
    |> put_in(["url"], file.url)
    |> put_in(["bytes"], file.bytes)
    |> put_in(["sha256"], file.sha256)
  end

  defp missing(chants, source) do
    for chant <- chants,
        name <- ["#{chant["id"]}.m4a" | Enum.map(chant["score"], &"Scores/#{&1["file"]}.lvscore")],
        not File.exists?(Path.join(source, name)),
        do: name
  end

  # A chant id and a score's file name become a path under `source` and a
  # bucket key, so they are checked before either is built.
  defp named(document) do
    names =
      for chant <- document["chants"],
          name <- [chant["id"] | Enum.map(chant["score"], & &1["file"])],
          do: name

    case Enum.reject(names, &(is_binary(&1) and &1 =~ ~r/\A[A-Za-z0-9_-]+\z/)) do
      [] ->
        :ok

      bad ->
        {:error,
         "a chant id or score file may hold only letters, digits, _ and -: #{inspect(bad)}"}
    end
  end

  defp read(path), do: path |> File.read!() |> Jason.decode!(objects: :ordered_objects)

  defp prayer_ids(path) do
    path |> File.read!() |> Jason.decode!() |> Map.fetch!("prayers") |> Enum.map(& &1["id"])
  end

  # The document with its date first, as every file in priv/library holds it.
  defp dated(%Jason.OrderedObject{values: values}, updated_at) do
    Jason.OrderedObject.new([
      {"updated_at", updated_at} | Enum.reject(values, &match?({"updated_at", _}, &1))
    ])
  end

  defp check(document, prayer_ids) do
    case Library.chant_library_errors(plain(document), prayer_ids, public_base()) do
      [] -> :ok
      errors -> {:error, "the rewritten file would not compile:\n  " <> Enum.join(errors, "\n  ")}
    end
  end

  # Each file once (chants share score pages), in key order, skipping what
  # the bucket already holds. A dry run asks the bucket nothing.
  defp store(files, _storage, true), do: {:ok, files |> Enum.map(& &1.key) |> Enum.sort(), []}

  defp store(files, storage, _dry_run) do
    files
    |> Enum.sort_by(& &1.key)
    |> Enum.reduce_while({:ok, [], []}, fn file, {:ok, uploaded, present} ->
      with {:ok, false} <- storage.audio_exists?(file.key, bucket: public_bucket()),
           {:ok, _key} <-
             storage.upload_public(File.read!(file.path), file.key,
               content_type: file.content_type
             ) do
        {:cont, {:ok, [file.key | uploaded], present}}
      else
        {:ok, true} -> {:cont, {:ok, uploaded, [file.key | present]}}
        {:error, reason} -> {:halt, {:error, "#{file.key}: #{inspect(reason)}"}}
      end
    end)
    |> case do
      {:ok, uploaded, present} -> {:ok, Enum.reverse(uploaded), Enum.reverse(present)}
      error -> error
    end
  end

  # Where public files are served from: a key's URL without the key.
  defp public_base, do: String.replace_suffix(S3.public_url("chants"), "/chants", "")

  defp public_bucket, do: Application.get_env(:lumen_viae, :aws_s3_public_bucket)

  defp stamp(nil), do: stamp(DateTime.utc_now())

  defp stamp(now),
    do: now |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  # The document as plain maps, to compare and to check.
  defp plain(document),
    do: document |> Jason.encode!() |> Jason.decode!() |> Map.delete("updated_at")

  defp encode(document), do: Jason.encode!(document, pretty: true) <> "\n"
end
