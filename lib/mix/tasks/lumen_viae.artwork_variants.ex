defmodule Mix.Tasks.LumenViae.ArtworkVariants do
  @shortdoc "Makes the WebP display variants of paintings that do not have them yet"

  @moduledoc """
  Makes the display variants of every stored painting that is missing
  some, leaving the original untouched. See
  `LumenViae.Curation.ArtworkVariants`.

      mix lumen_viae.artwork_variants --dry-run
      mix lumen_viae.artwork_variants

  ## Options

    * `--dry-run` - list the paintings that need variants; nothing is
      downloaded, uploaded or written

  Always dry-run first. Idempotent: a second run skips everything the
  first one finished. In production use
  `LumenViae.Release.artwork_variants/1` (docs/MYSTERY_PAINTINGS.md).
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} = OptionParser.parse(args, strict: [dry_run: :boolean])

    if invalid != [], do: Mix.raise("Invalid options: #{inspect(invalid)}")

    dry_run = opts[:dry_run] || false

    results =
      LumenViae.Curation.ArtworkVariants.run(
        dry_run: dry_run,
        progress: &progress/1,
        # An operator's shell already holds the database credentials, and
        # there is no signed-in admin to act as.
        authorize?: false
      )

    errors = Enum.count(results, &match?({:error, _}, &1))
    warnings = Enum.count(results, &match?({:warning, _}, &1))
    suffix = if dry_run, do: " (dry run: nothing was changed)", else: ""

    Mix.shell().info(
      "\n#{length(results) - errors - warnings} succeeded, #{warnings} with warnings, " <>
        "#{errors} failed#{suffix}"
    )

    if errors > 0, do: exit({:shutdown, 1})
  end

  defp progress({:started, total}), do: Mix.shell().info("#{total} painting(s) need variants")

  defp progress({:item_finished, index, total, {status, message}}) do
    line = "[#{index}/#{total}] #{message}"

    case status do
      :ok -> Mix.shell().info("OK    " <> line)
      :warning -> Mix.shell().info("WARN  " <> line)
      :error -> Mix.shell().error("ERROR " <> line)
    end
  end
end
