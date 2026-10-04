defmodule Mix.Tasks.LumenViae.Doctor do
  @shortdoc "Checks that this machine can run, test and record for Lumen Viae"
  @moduledoc """
  Checks the things that make a working checkout, and says what to do
  about each one that fails:

      mix lumen_viae.doctor

    * the toolchain against the Dockerfile's (what CI and production build with)
    * `.env`, and the credentials in it that the audio pipeline needs
    * the database: reachable, which one, and no migration left to run
    * the dev server's port, and a test partition in a worktree
    * the audio bucket, the Office engine, geolocation and ElevenLabs,
      through the same probes as the console's System screen

  Each line is `ok`, `warn` (works, but something will not) or `FAIL`
  (something will not start). The task exits non-zero on any `FAIL`.

  It does not start the app, so it still runs when the database is down,
  and it never writes anything. Run it with the environment the dev server
  gets: `./dev.sh doctor`, or `set -a; source .env; set +a` first.
  """
  use Mix.Task

  alias LumenViae.Ops

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_args) do
    for app <- [:req, :ex_aws, :postgrex, :ecto_sql], do: Application.ensure_all_started(app)

    results =
      Enum.flat_map(
        [
          &toolchain/0,
          &env_file/0,
          &credentials/0,
          &database/0,
          &port/0,
          &partition/0,
          &probes/0
        ],
        & &1.()
      )

    Enum.each(results, fn {level, name, detail} ->
      Mix.shell().info(
        String.pad_trailing(label(level), 6) <> String.pad_trailing(name, 23) <> detail
      )
    end)

    case Enum.count(results, &match?({:fail, _, _}, &1)) do
      0 -> Mix.shell().info("\nNothing stands in the way.")
      n -> Mix.raise("#{n} check(s) failed; see above.")
    end
  end

  defp label(:ok), do: "ok"
  defp label(:warn), do: "warn"
  defp label(:fail), do: "FAIL"

  defp toolchain do
    dockerfile = File.read!("Dockerfile")
    [_, elixir] = Regex.run(~r/ARG ELIXIR_VERSION=(\S+)/, dockerfile)
    [_, otp] = Regex.run(~r/ARG OTP_VERSION=(\d+)/, dockerfile)
    here = "Elixir #{System.version()}, OTP #{System.otp_release()}"

    if System.version() == elixir and System.otp_release() == otp,
      do: [{:ok, "Toolchain", here}],
      else: [{:warn, "Toolchain", "#{here}; CI and production use Elixir #{elixir}, OTP #{otp}"}]
  end

  defp env_file do
    if File.exists?(".env"),
      do: [{:ok, ".env", "present"}],
      else: [{:warn, ".env", "missing: the audio players and recordings need its AWS keys"}]
  end

  defp credentials do
    [
      {"AWS_ACCESS_KEY_ID", "audio playback and uploads"},
      {"AWS_SECRET_ACCESS_KEY", "audio playback and uploads"},
      {"ELEVEN_LABS_API_KEY", "recording narration"}
    ]
    |> Enum.map(fn {var, use} ->
      if System.get_env(var) in [nil, ""],
        do: {:warn, var, "not set: no #{use} (did you run through ./dev.sh?)"},
        else: {:ok, var, "set"}
    end)
  end

  defp database do
    repo = LumenViae.Repo
    name = repo.config()[:database] || "(from DATABASE_URL)"

    case start_repo(repo) do
      :ok ->
        pending =
          repo
          |> Ecto.Migrator.migrations()
          |> Enum.count(&match?({:down, _, _}, &1))

        migrations =
          if pending == 0,
            do: {:ok, "Migrations", "all applied"},
            else: {:fail, "Migrations", "#{pending} pending: run `mix ash.migrate`"}

        [{:ok, "Database", "#{name} reachable"}, migrations]

      {:error, reason} ->
        [
          {:fail, "Database",
           "#{name} unreachable (#{reason}). Is Postgres running? " <>
             "`mix ash.setup` creates it; DEV_DATABASE picks a copy"}
        ]
    end
  end

  defp start_repo(repo) do
    case repo.start_link(pool_size: 2, log: false) do
      {:ok, _pid} -> ping(repo)
      {:error, {:already_started, _pid}} -> ping(repo)
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp ping(repo) do
    case repo.query("SELECT 1", [], timeout: 3_000) do
      {:ok, _result} -> :ok
      {:error, error} -> {:error, Exception.message(error)}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp port do
    port = String.to_integer(System.get_env("PORT", "8080"))

    case :gen_tcp.listen(port, reuseaddr: true) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        [{:ok, "Port #{port}", "free for ./dev.sh"}]

      {:error, :eaddrinuse} ->
        [{:warn, "Port #{port}", "in use (another worktree's server?): PORT=8081 ./dev.sh"}]

      {:error, reason} ->
        [{:warn, "Port #{port}", inspect(reason)}]
    end
  end

  # A worktree's .git is a file. Worktrees share the test database unless
  # each sets its own partition (CLAUDE.md, "Local Development").
  defp partition do
    cond do
      not File.regular?(".git") ->
        []

      System.get_env("MIX_TEST_PARTITION") in [nil, ""] ->
        [
          {:warn, "Test DB",
           "this is a worktree: export MIX_TEST_PARTITION=<name> before mix test"}
        ]

      true ->
        [{:ok, "Test DB", "partition #{System.get_env("MIX_TEST_PARTITION")}"}]
    end
  end

  defp probes do
    Enum.map(Ops.probe_names(), fn name ->
      %{status: status, detail: detail} = Ops.probe(name)
      # Off is how geolocation ships in development; anything else that is
      # off or failing works without it but loses something.
      level =
        case {name, status} do
          {_name, :ok} -> :ok
          {:geolocation, :off} -> :ok
          _off_or_failing -> :warn
        end

      {level, name |> to_string() |> String.replace("_", " "), detail}
    end)
  end
end
