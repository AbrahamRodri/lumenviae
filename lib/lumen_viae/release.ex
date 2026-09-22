defmodule LumenViae.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :lumen_viae

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    # Run seeds idempotently after migrations
    # This adds new meditations/mysteries without wiping existing data
    # System.put_env("FORCE_SEED", "true")
    # seed()
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          # Run the seed script
          seed_script = Path.join([:code.priv_dir(@app), "repo", "seeds.exs"])

          if File.exists?(seed_script) do
            Code.eval_file(seed_script)
          end
        end)
    end
  end

  @doc """
  Imports meditations from a CSV file inside a production release, where Mix
  tasks are unavailable. Accepts the same options as
  `LumenViae.Curation.CsvImport.import_string/2`.

      /app/bin/lumen_viae eval 'LumenViae.Release.import_csv("/tmp/file.csv")'
  """
  def import_csv(path, opts \\ []) do
    load_app()
    start_audio_clients()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          results = LumenViae.Curation.CsvImport.import_file(path, opts)

          Enum.each(results, fn
            {:ok, message} -> IO.puts("OK    " <> message)
            {:warning, message} -> IO.puts("WARN  " <> message)
            {:error, message} -> IO.puts("ERROR " <> message)
          end)

          results
        end)
    end

    :ok
  end

  @doc """
  Regenerates ElevenLabs audio inside a production release, replacing the
  S3 objects so already-imported meditations pick up new pause logic, a new
  model, or a new voice without re-importing. Takes one of `set: "Set
  Name"`, `id: 42` or `all: true`, plus the options of
  `LumenViae.Curation.AudioRegeneration.run/2`: `voices: ["female"]`,
  `only_missing: true`, `dry_run: true`.

      /app/bin/lumen_viae eval 'LumenViae.Release.regenerate_audio(set: "Set Name", dry_run: true)'
      /app/bin/lumen_viae eval 'LumenViae.Release.regenerate_audio(all: true, voices: ["female"], only_missing: true)'
  """
  def regenerate_audio(opts) do
    load_app()
    start_audio_clients()

    target =
      case {opts[:set], opts[:id], opts[:all]} do
        {set_name, nil, nil} when is_binary(set_name) ->
          {:set, set_name}

        {nil, id, nil} when is_integer(id) ->
          {:meditation, id}

        {nil, nil, true} ->
          :all

        _ ->
          raise ArgumentError, "pass one of set: \"Set Name\", id: 42 or all: true"
      end

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          LumenViae.Curation.AudioRegeneration.run(target,
            voices: Keyword.get(opts, :voices),
            only_missing: Keyword.get(opts, :only_missing, false),
            dry_run: Keyword.get(opts, :dry_run, false),
            progress: &print_progress/1
          )
        end)
    end

    :ok
  end

  @doc """
  Copies every original narration - the root-level object each
  meditation's `audio_url` used to name - to its place under the male voice
  prefix, `voices/male/<filename>`, where the narrations table now expects
  it. Server-side copies: nothing is downloaded, and the originals are left
  in place to be deleted by hand once the new layout has been verified.

  Idempotent: an object already at its destination is skipped, so the task
  can be re-run after a partial failure. Run it once, around the deploy
  that introduces voices (see docs/CSV_IMPORT_GUIDE.md):

      /app/bin/lumen_viae eval 'LumenViae.Release.copy_narration_to_voice_prefix()'
  """
  def copy_narration_to_voice_prefix do
    load_app()
    start_audio_clients()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          LumenViae.Curation.NarrationRelocation.run(progress: &print_progress/1)
        end)
    end

    :ok
  end

  defp print_progress({:started, total}), do: IO.puts("Processing #{total} item(s)")

  defp print_progress({:item_finished, index, total, {status, message}}) do
    prefix =
      case status do
        :ok -> "OK   "
        :warning -> "WARN "
        :error -> "ERROR"
      end

    IO.puts("#{prefix} [#{index}/#{total}] #{message}")
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end

  # `bin/lumen_viae eval` boots a bare node with no applications started,
  # but the audio pipeline needs Req (ElevenLabs) and ExAws over hackney
  # (S3 uploads). Without these, the first audio row would crash the eval
  # node with a noproc instead of degrading to a warning.
  defp start_audio_clients do
    for app <- [:req, :ex_aws, :hackney] do
      {:ok, _} = Application.ensure_all_started(app)
    end

    :ok
  end
end
