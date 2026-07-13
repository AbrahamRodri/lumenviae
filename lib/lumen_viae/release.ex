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
  `LumenViae.Meditations.CsvImport.import_string/2`.

      /app/bin/lumen_viae eval 'LumenViae.Release.import_csv("/tmp/file.csv")'
  """
  def import_csv(path, opts \\ []) do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          results = LumenViae.Meditations.CsvImport.import_file(path, opts)

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
  existing S3 files so already-imported meditations pick up new pause logic
  without re-importing. Takes `set: "Set Name"` or `id: 42`, plus optional
  `dry_run: true`.

      /app/bin/lumen_viae eval 'LumenViae.Release.regenerate_audio(set: "Set Name", dry_run: true)'
  """
  def regenerate_audio(opts) do
    load_app()

    target =
      case {opts[:set], opts[:id]} do
        {set_name, nil} when is_binary(set_name) ->
          {:set, set_name}

        {nil, id} when is_integer(id) ->
          {:meditation, id}

        _ ->
          raise ArgumentError, "pass either set: \"Set Name\" or id: 42"
      end

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          LumenViae.Meditations.AudioRegeneration.run(target,
            dry_run: Keyword.get(opts, :dry_run, false),
            progress: fn
              {:started, total} ->
                IO.puts("Processing #{total} meditation(s)")

              {:item_finished, index, total, {status, message}} ->
                prefix =
                  case status do
                    :ok -> "OK   "
                    :warning -> "WARN "
                    :error -> "ERROR"
                  end

                IO.puts("#{prefix} [#{index}/#{total}] #{message}")
            end
          )
        end)
    end

    :ok
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
