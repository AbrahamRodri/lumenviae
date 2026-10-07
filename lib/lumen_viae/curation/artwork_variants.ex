defmodule LumenViae.Curation.ArtworkVariants do
  @moduledoc """
  Makes the display variants of paintings uploaded before they existed, or
  whose variants could not all be made at upload.

  For every set, author, mystery and category card with a stored painting
  whose `image_variant_widths` is not yet every width
  `LumenViae.Images.Variants.widths_for/1` gives its original, it
  downloads the original, makes and stores the variants through
  `LumenViae.Curation.ArtworkUpload.store_variants/2`, and records the
  widths now in S3. The original is never changed.

  It also corrects the size of a painting recorded sideways. The upload
  once read a JPEG's stored geometry and ignored its Exif orientation, so a
  photograph tagged with a quarter turn was recorded with its width and
  height swapped, and its variants, made the way it is shown, never matched
  the widths expected from that width: it stayed pending on every run. The
  size is now read from the original downloaded, as it is shown
  (`LumenViae.Images.Inspector`), and recorded with the widths.

  Idempotent: a painting that already has all its variants is skipped, so
  a run cut short can simply be repeated. A dry run reads the database and
  nothing else - no download, no upload, no write - and lists what a real
  run would make.

  Used by `mix lumen_viae.artwork_variants` and
  `LumenViae.Release.artwork_variants/1`.

  ## Options

    * `:dry_run` - list the paintings that need variants; change nothing
    * `:progress` - a 1-arity function receiving `{:started, total}` and
      `{:item_finished, index, total, result}` events
    * `:actor` / `:authorize?` - who the run reads and writes as;
      `authorize?: false` only from an operator's shell
  """

  alias LumenViae.AshOpts
  alias LumenViae.Curation.ArtworkUpload
  alias LumenViae.Images.Inspector
  alias LumenViae.Images.Variants
  alias LumenViae.Rosary
  alias LumenViae.Storage.S3

  @type result :: {:ok | :warning | :error, String.t()}

  @spec run(keyword) :: [result]
  def run(opts \\ []) do
    ash_opts = AshOpts.take(opts)

    pending =
      ash_opts
      |> paintings()
      |> Enum.filter(&pending?/1)

    total = length(pending)
    notify(opts, {:started, total})

    pending
    |> Enum.with_index(1)
    |> Enum.map(fn {painting, index} ->
      result =
        if opts[:dry_run], do: describe(painting), else: backfill(painting, ash_opts)

      notify(opts, {:item_finished, index, total, result})
      result
    end)
  end

  @doc """
  Counts a run's results for whoever started it: `succeeded`, `warnings`
  (an original missing from the bucket), `failed` (a variant that could
  not be stored, a download or a write that failed) and `failures`, the
  failed paintings' messages.
  """
  @spec summarize([{:ok | :warning | :error, String.t()}]) :: %{
          succeeded: non_neg_integer,
          warnings: non_neg_integer,
          failed: non_neg_integer,
          failures: [String.t()]
        }
  def summarize(results) do
    failures = for {:error, message} <- results, do: message
    warnings = Enum.count(results, &match?({:warning, _}, &1))

    %{
      succeeded: length(results) - warnings - length(failures),
      warnings: warnings,
      failed: length(failures),
      failures: failures
    }
  end

  defp pending?(%{record: record}), do: missing(record) != []

  # Each kind of record that carries artwork, with the write that records
  # its variants. Every record with a stored painting, published or not:
  # a painting waiting for its alt text should have its variants ready.
  defp paintings(ash_opts) do
    [
      {"set", Rosary.list_meditation_sets!(ash_opts),
       &Rosary.record_meditation_set_artwork_variants/3},
      {"author", Rosary.list_authors!(ash_opts), &Rosary.record_author_artwork_variants/3},
      {"mystery", Rosary.list_mysteries!(ash_opts), &Rosary.record_mystery_artwork_variants/3},
      {"category card", Rosary.list_category_cards!(ash_opts),
       &Rosary.record_category_card_artwork_variants/3}
    ]
    |> Enum.flat_map(fn {kind, records, record_fun} ->
      records
      |> Enum.filter(&(is_binary(&1.image_key) and &1.image_key != "" and &1.image_width))
      |> Enum.sort_by(& &1.id)
      |> Enum.map(&%{kind: kind, record: &1, record_fun: record_fun})
    end)
  end

  defp missing(record) do
    Variants.widths_for(record.image_width) -- (record.image_variant_widths || [])
  end

  defp describe(%{kind: kind, record: record}) do
    {:ok,
     "Would make #{Enum.join(missing(record), ", ")}px variants of #{record.image_key} " <>
       "(#{kind} #{record.id}, #{record.image_width}x#{record.image_height})"}
  end

  defp backfill(%{kind: kind, record: record, record_fun: record_fun}, ash_opts) do
    key = record.image_key
    label = "#{kind} #{record.id}"

    # Variants are named after their key and never change, so the ones
    # recorded before are still there: this run adds to them. A width that
    # fails this time must not take one stored earlier off the page.
    recorded = record.image_variant_widths || []

    with {:ok, original} <- download(key, label),
         {shown_width, shown_height} = shown_size(original, record),
         expected = Variants.widths_for(shown_width),
         {:ok, stored} <- ArtworkUpload.store_variants(original, key),
         widths = Enum.sort(Enum.uniq(recorded ++ stored)),
         changes = changes(record, widths, shown_width, shown_height),
         :ok <- record_changes(record_fun, record, changes, label, ash_opts) do
      # A variant that could not be stored is a failure, not a warning:
      # the bucket refused it or the original would not resize, and a run
      # that ends this way must say so to whoever started it.
      if widths == expected do
        {:ok, "Made #{Enum.join(widths, ", ")}px variants of #{key} (#{label})"}
      else
        {:error,
         "Made only #{inspect(widths)} of #{inspect(expected)}px variants of #{key} " <>
           "(#{label}); run again to retry the rest"}
      end
    end
  end

  # The painting's size as it is shown, read from the original itself; the
  # recorded size if the header cannot be read (the variants are made from
  # the decoded picture either way).
  defp shown_size(original, record) do
    case Inspector.inspect(original) do
      {:ok, %{width: width, height: height}} -> {width, height}
      {:error, _reason} -> {record.image_width, record.image_height}
    end
  end

  # Only what differs from the record is written.
  defp changes(record, widths, width, height) do
    %{image_variant_widths: widths, image_width: width, image_height: height}
    |> Enum.reject(fn {field, value} -> Map.get(record, field) == value end)
    |> Map.new()
  end

  defp download(key, label) do
    case S3.get_public(key) do
      {:ok, original} -> {:ok, original}
      {:error, :not_found} -> {:warning, "No object at #{key} (#{label}); nothing to resize"}
      {:error, reason} -> {:error, "Could not download #{key} (#{label}): #{inspect(reason)}"}
    end
  end

  defp record_changes(_record_fun, _record, changes, _label, _ash_opts)
       when map_size(changes) == 0,
       do: :ok

  defp record_changes(record_fun, record, changes, label, ash_opts) do
    params = Map.put(changes, :for_image_key, record.image_key)

    case record_fun.(record, params, ash_opts) do
      {:ok, _record} ->
        :ok

      {:error, error} ->
        {:error, "Could not record the variants of #{label}: #{Rosary.error_summary(error)}"}
    end
  end

  defp notify(opts, event) do
    case opts[:progress] do
      fun when is_function(fun, 1) -> fun.(event)
      _ -> :ok
    end
  end
end
