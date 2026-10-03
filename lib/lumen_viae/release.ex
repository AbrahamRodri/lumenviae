defmodule LumenViae.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :lumen_viae

  # The tasks here run from an operator's shell, which already holds the
  # database credentials, and there is no signed-in admin to act as, so
  # every domain call they make skips the policies.
  @operator [authorize?: false]

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
  `LumenViae.Curation.CsvImport.import_string/2`, plus `wait: false`.

      /app/bin/lumen_viae eval 'LumenViae.Release.import_csv("/tmp/file.csv")'

  The rows are written here; each narration is enqueued as a job, which the
  running app records on its `elevenlabs` queue. This task then waits for
  the recordings and prints them as they finish, unless `wait: false`
  (the jobs carry on either way; follow them at `/admin/jobs`). See
  "Recording jobs from a release task" below.
  """
  def import_csv(path, opts \\ []) do
    load_app()
    start_audio_clients()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          with_audio_jobs(opts, fn opts ->
            results =
              LumenViae.Curation.CsvImport.import_file(path, Keyword.merge(opts, @operator))

            print_results(results)
          end)
        end)
    end

    :ok
  end

  @doc """
  Replaces the text of existing meditations from a CSV inside a production
  release and re-records them. Accepts the options of
  `LumenViae.Curation.CsvUpdate.update_string/2`.

      /app/bin/lumen_viae eval 'LumenViae.Release.update_csv("/tmp/fixes.csv", dry_run: true)'
  """
  def update_csv(path, opts \\ []) do
    load_app()
    start_audio_clients()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          with_audio_jobs(opts, fn opts ->
            results =
              LumenViae.Curation.CsvUpdate.update_file(path, Keyword.merge(opts, @operator))

            print_results(results)
          end)
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
  `only_missing: true`, `force: true`, `dry_run: true`, and `wait: false`.
  The recordings are jobs the running app does; see "Recording jobs from
  a release task" below.

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
          with_audio_jobs(opts, fn opts ->
            LumenViae.Curation.AudioRegeneration.run(
              target,
              [
                voices: Keyword.get(opts, :voices),
                only_missing: Keyword.get(opts, :only_missing, false),
                force: Keyword.get(opts, :force, false),
                dry_run: Keyword.get(opts, :dry_run, false),
                batch: opts[:batch],
                progress: &print_progress/1
              ] ++ @operator
            )
          end)
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
          LumenViae.Curation.NarrationRelocation.run([progress: &print_progress/1] ++ @operator)
        end)
    end

    :ok
  end

  @doc """
  Records the spoken Rosary's prayers, announcements and verses with
  ElevenLabs, skipping every clip already in the bucket. Takes the options
  of `LumenViae.Curation.RosaryAudioGeneration.run/1` (`voices:`, `kinds:`,
  `force:`, `dry_run:`), plus `wait: false`. The clips go to S3, not to a
  table; the database holds only the jobs, which the running app records
  (see "Recording jobs from a release task" below). A dry run touches no
  database:

      /app/bin/lumen_viae eval 'LumenViae.Release.generate_rosary_audio(dry_run: true)'
      /app/bin/lumen_viae eval 'LumenViae.Release.generate_rosary_audio()'
  """
  def generate_rosary_audio(opts \\ []) do
    load_app()
    start_audio_clients()

    run = fn opts ->
      opts
      |> Keyword.put(:progress, &print_progress/1)
      |> LumenViae.Curation.RosaryAudioGeneration.run()
    end

    if opts[:dry_run] do
      run.(opts)
    else
      for repo <- repos() do
        {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _repo -> with_audio_jobs(opts, run) end)
      end
    end

    :ok
  end

  # Recording jobs from a release task.
  #
  # `eval` starts the release without the application, so there is no Oban
  # here to run jobs, and no queue on this node to run them on. The task
  # starts an Oban that only inserts (AudioJobs.start_inserter/0), enqueues
  # under one batch, and the running app records them on its elevenlabs
  # queue. Then, unless wait: false, it reads the batch from the jobs table
  # every five seconds until every job has finished, and prints the
  # failures. That keeps working when the task is run detached (setsid -f,
  # output to a log file): nothing it waits on is in this process.
  defp with_audio_jobs(opts, fun) do
    LumenViae.Curation.AudioJobs.start_inserter()
    batch = LumenViae.Curation.AudioJobs.new_batch()
    {wait?, opts} = Keyword.pop(opts, :wait, true)
    result = fun.(Keyword.put(opts, :batch, batch))

    if wait? and not Keyword.get(opts, :dry_run, false) do
      IO.puts("Waiting for the recordings (batch #{batch}); they run on the app's queue")
      LumenViae.Curation.AudioJobs.follow(batch, &IO.puts/1)
    end

    result
  end

  defp print_results(results) do
    Enum.each(results, fn
      {:ok, message} -> IO.puts("OK    " <> message)
      {:warning, message} -> IO.puts("WARN  " <> message)
      {:error, message} -> IO.puts("ERROR " <> message)
    end)

    results
  end

  @doc """
  Creates a console admin and prints a generated password, once. Nothing
  stores the password in the clear, so copy it before closing the shell.

      /app/bin/lumen_viae eval 'LumenViae.Release.create_admin("you@example.com")'

  Returns `{:ok, password}` or `{:error, summary}` (an address that is
  already an admin, say). Runs with `authorize?: false`: there is no admin
  to act as before the first one exists, and whoever holds this shell
  already holds the database.
  """
  def create_admin(email) when is_binary(email) do
    password = LumenViae.Accounts.generate_password()

    with_repo(fn ->
      case LumenViae.Accounts.create_admin(email, password, authorize?: false) do
        {:ok, admin} ->
          print_password("Created admin #{admin.email}", password)
          {:ok, password}

        {:error, error} ->
          IO.puts("ERROR could not create admin #{email}: #{Exception.message(error)}")
          {:error, Exception.message(error)}
      end
    end)
  end

  @doc """
  Replaces an admin's password with a generated one, prints it once, and
  signs that admin out everywhere.

      /app/bin/lumen_viae rpc 'LumenViae.Release.reset_admin_password("you@example.com")'

  Run it with `rpc`, inside the running app, not `eval`. Either way every
  token the admin holds is revoked. Only inside the running app can it also
  close the console tabs they already have open (`LumenViaeWeb.AdminSockets`);
  under `eval` those tabs keep working until they next mount a page.

  Returns `{:ok, password}`, `{:error, :not_found}` for an address that is
  not an admin, or `{:error, message}` when the lookup or the update itself
  fails. `authorize?: false` for the reason `create_admin/1`
  gives.
  """
  def reset_admin_password(email) when is_binary(email) do
    password = LumenViae.Accounts.generate_password()

    with_repo(fn ->
      case LumenViae.Accounts.get_admin_by_email(email, authorize?: false) do
        {:ok, admin} ->
          replace_password(admin, password)

        {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} ->
          IO.puts("ERROR no admin with the email #{email}")
          {:error, :not_found}

        {:error, error} ->
          IO.puts("ERROR could not look up #{email}: #{Exception.message(error)}")
          {:error, Exception.message(error)}
      end
    end)
  end

  # The admin exists, so a failure here is not "no such admin": say what it
  # was, so the operator fixes it rather than retrying another address.
  defp replace_password(admin, password) do
    case LumenViae.Accounts.set_admin_password(admin, password, authorize?: false) do
      {:ok, admin} ->
        disconnect_sockets(admin)
        print_password("New password for #{admin.email}", password)
        {:ok, password}

      {:error, error} ->
        IO.puts(
          "ERROR could not reset the password for #{admin.email}: #{Exception.message(error)}"
        )

        {:error, Exception.message(error)}
    end
  end

  # Only a running app has an endpoint to broadcast through; a bare `eval`
  # node does not, and is not in the cluster either.
  defp disconnect_sockets(admin) do
    if Process.whereis(LumenViaeWeb.Endpoint) do
      LumenViaeWeb.AdminSockets.disconnect(admin)
    else
      IO.puts("WARN  not inside the running app: open console tabs stay open until they reload")
    end
  end

  defp print_password(heading, password) do
    IO.puts("""
    #{heading}.
    Password (shown once, not stored anywhere in the clear):

        #{password}
    """)
  end

  # Runs `fun` with the repo started, as every task here must in a bare
  # `eval` node, and returns its result.
  defp with_repo(fun) do
    load_app()
    [repo | _] = repos()
    {:ok, result, _apps} = Ecto.Migrator.with_repo(repo, fn _repo -> fun.() end)
    result
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
  # but the audio pipeline needs Req, which carries both ElevenLabs and
  # ExAws's S3 uploads (config :ex_aws, http_client). Without these, the
  # first audio row would crash the eval node with a noproc instead of
  # degrading to a warning.
  defp start_audio_clients do
    for app <- [:req, :ex_aws] do
      {:ok, _} = Application.ensure_all_started(app)
    end

    :ok
  end
end
