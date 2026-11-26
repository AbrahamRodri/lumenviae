defmodule LumenViae.Curation.ArtworkReplacement do
  @moduledoc """
  Replaces the painting a set shows with a new original, from an
  operator's shell: the console's upload, for when the file is on the
  server rather than in a browser.

  For each set id it finds the record whose painting the set shows
  (`LumenViae.Rosary.artwork_record/1`: the set's own artwork, or the
  linked author's portrait), so a portrait shared through an author is
  replaced once for every set under that author. Each record gets the new
  file through `LumenViae.Curation.ArtworkUpload.upload/3`, the same path
  the console takes: the same rules, a new content-addressed key, the
  480, 960 and 1600 WebP variants made for that key and recorded with it.
  The old original and its variants stay in the bucket, so a client
  holding an old URL still loads it.

  Each record keeps its own focal point unless `:focal` is given, and its
  credit unless `:attribution` names fields to change.

  Rolling back is replacing again with the old original: download it from
  the before URL this prints and run the task with that file. The key is
  the hash of the bytes, so the record points at its old key again.

  ## Options

    * `:dry_run` - check the file and print what would change; upload and
      write nothing
    * `:focal` - `{x, y}`, each 0.0 to 1.0, for every record replaced
    * `:attribution` - a keyword list of `:title`, `:artist`, `:year`,
      `:source_url`, `:license`, written to every record replaced
    * `:actor` / `:authorize?` - who the run reads and writes as;
      `authorize?: false` only from an operator's shell
  """

  alias LumenViae.AshOpts
  alias LumenViae.Curation.ArtworkUpload
  alias LumenViae.Rosary

  @attribution_fields %{
    title: :image_title,
    artist: :image_artist,
    year: :image_year,
    source_url: :image_source_url,
    license: :image_license
  }

  @type result :: {:ok | :error, String.t()}

  @doc """
  Replaces the painting shown by every set in `set_ids` with `binary`.
  Returns one result per record (not per set), each naming the before and
  after URLs.
  """
  @spec run([pos_integer], binary, keyword) :: [result]
  def run(set_ids, binary, opts \\ []) when is_list(set_ids) and is_binary(binary) do
    ash_opts = AshOpts.take(opts)

    with {:ok, extra} <- extra_fields(opts) do
      set_ids
      |> Enum.map(&target(&1, ash_opts))
      |> Enum.uniq_by(fn
        {:ok, %{scope: scope, record: record}} -> {scope, record.id}
        error -> error
      end)
      |> Enum.map(fn
        {:ok, target} -> replace(target, binary, extra, opts, ash_opts)
        error -> error
      end)
    else
      error -> [error]
    end
  end

  # The record a set shows, and the write that records an upload on it.
  defp target(set_id, ash_opts) do
    case Rosary.get_meditation_set(set_id, [load: [:author_profile]] ++ ash_opts) do
      {:ok, set} ->
        case Rosary.artwork_record(set) do
          nil ->
            {:error, "Set #{set_id} shows no painting; nothing to replace"}

          ^set ->
            {:ok, %{scope: :set, record: set, write: &Rosary.update_meditation_set_artwork/3}}

          author ->
            {:ok, %{scope: :author, record: author, write: &Rosary.update_author_artwork/3}}
        end

      {:error, _} ->
        {:error, "No set #{set_id}"}
    end
  end

  defp replace(%{scope: scope, record: record} = target, binary, extra, opts, ash_opts) do
    label = "#{scope} #{record.id}"
    before_url = Rosary.artwork_url(record)

    with {:ok, %{key: key, info: info}} <-
           prepared(ArtworkUpload.prepare(binary, scope, record.id), label) do
      focal = Map.merge(record_focal(record), Map.take(extra, [:image_focal_x, :image_focal_y]))
      changed = Map.reject(extra, fn {field, value} -> Map.get(record, field) == value end)

      summary =
        "#{label}: #{before_url} -> #{Rosary.artwork_url(%{image_key: key})} " <>
          "(#{info.width}x#{info.height}, focal #{focal.image_focal_x}, #{focal.image_focal_y})"

      cond do
        key == record.image_key and changed == %{} ->
          {:ok, "#{label} already shows this painting (#{before_url}); nothing to do"}

        opts[:dry_run] ->
          {:ok, "Would replace " <> summary}

        true ->
          upload_and_record(target, binary, extra, summary, label, ash_opts)
      end
    end
  end

  defp upload_and_record(
         %{scope: scope, record: record, write: write},
         binary,
         extra,
         summary,
         label,
         ash_opts
       ) do
    with {:ok, fields} <- uploaded(ArtworkUpload.upload(binary, scope, record.id), label),
         params = Map.merge(fields, Map.new(extra, fn {k, v} -> {to_string(k), v} end)),
         {:ok, _record} <- written(write.(record, params, ash_opts), label) do
      {:ok, "Replaced " <> summary <> ", variants #{inspect(fields["image_variant_widths"])}"}
    end
  end

  defp record_focal(record),
    do: %{image_focal_x: record.image_focal_x, image_focal_y: record.image_focal_y}

  # The focal point and credit fields every record gets, checked before
  # anything is uploaded.
  defp extra_fields(opts) do
    with {:ok, focal} <- focal(opts[:focal]),
         {:ok, attribution} <- attribution(opts[:attribution] || []) do
      {:ok, Map.merge(focal, attribution)}
    end
  end

  defp focal(nil), do: {:ok, %{}}

  defp focal({x, y})
       when is_number(x) and is_number(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1,
       do: {:ok, %{image_focal_x: x / 1, image_focal_y: y / 1}}

  defp focal(other), do: {:error, "focal must be {x, y}, each 0.0 to 1.0; got #{inspect(other)}"}

  defp attribution(fields) do
    Enum.reduce_while(fields, {:ok, %{}}, fn {name, value}, {:ok, acc} ->
      case Map.fetch(@attribution_fields, name) do
        {:ok, column} -> {:cont, {:ok, Map.put(acc, column, value)}}
        :error -> {:halt, {:error, "Unknown attribution field #{inspect(name)}"}}
      end
    end)
  end

  defp prepared({:ok, prepared}, _label), do: {:ok, prepared}
  defp prepared({:error, message}, label), do: {:error, "#{label}: #{message}"}

  defp uploaded({:ok, fields}, _label), do: {:ok, fields}
  defp uploaded({:error, message}, label), do: {:error, "#{label}: #{message}"}

  defp written({:ok, record}, _label), do: {:ok, record}

  defp written({:error, error}, label),
    do: {:error, "#{label}: uploaded, but not recorded: #{Rosary.error_summary(error)}"}
end
