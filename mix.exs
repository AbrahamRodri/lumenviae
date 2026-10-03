defmodule LumenViae.MixProject do
  use Mix.Project

  def project do
    [
      app: :lumen_viae,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      usage_rules: usage_rules(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {LumenViae.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # The dependencies' own guidance for coding agents, gathered into one file.
  # Inlined rather than linked: deps/ is not in git, so links into it would be
  # dead for anyone reading the repo. Regenerate with `mix usage_rules.sync`.
  defp usage_rules do
    [
      file: "docs/USAGE_RULES.md",
      usage_rules: [:ash, ~r/^ash_/, :igniter, :usage_rules]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Ash: the domain layer, its Postgres data layer, LiveView forms and
      # the GraphQL API. See docs/ARCHITECTURE.md.
      {:ash, "~> 3.33"},
      {:ash_postgres, "~> 2.13"},
      {:ash_phoenix, "~> 2.3"},
      {:ash_graphql, "~> 1.12"},
      {:absinthe_plug, "~> 1.5"},
      {:ash_admin, "~> 1.3"},
      {:ash_paper_trail, "~> 0.7"},
      # Rate limits live on the actions they protect. See docs/ARCHITECTURE.md,
      # "Rate limits".
      {:ash_rate_limiter, "~> 2.0"},
      # The counters behind it: per-node, in ETS, fixed windows.
      {:hammer, "~> 7.5"},
      # Admin accounts: email and password sign-in for the console. See
      # docs/ARCHITECTURE.md, "Who may do what".
      {:ash_authentication, "~> 4.15"},
      {:ash_authentication_phoenix, "~> 2.17"},
      {:bcrypt_elixir, "~> 3.3"},
      # The SAT solver Ash's policy authorizer needs.
      {:picosat_elixir, "~> 0.2"},
      {:igniter, "~> 0.8", only: [:dev, :test]},
      {:sourceror, "~> 1.12", only: [:dev, :test]},
      {:usage_rules, "~> 1.2", only: :dev, runtime: false},
      # Static analysis and dependency audit, run by CI (docs/CI.md). Never
      # in the release: `mix deps.get --only prod` skips them.
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.16", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.7"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.3"},
      {:phoenix_live_reload, "~> 1.7", only: :dev},
      {:phoenix_live_view, "~> 1.2"},
      {:floki, ">= 0.30.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.9"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.28"},
      {:req, "~> 0.7"},
      {:telemetry_metrics, "~> 1.2"},
      {:telemetry_poller, "~> 1.3"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.3"},
      {:bandit, "~> 1.12"},
      {:nimble_csv, "~> 1.3"},
      {:ex_aws, "~> 2.7"},
      {:ex_aws_s3, "~> 2.5"},
      {:sweet_xml, "~> 0.7"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind lumen_viae", "esbuild lumen_viae"],
      "assets.deploy": [
        "tailwind lumen_viae --minify",
        "esbuild lumen_viae --minify",
        "phx.digest"
      ]
    ]
  end
end
