[
  import_deps: [
    :ash_graphql,
    :ash_json_api,
    :ash_paper_trail,
    :ash_oban,
    :oban_web,
    :absinthe,
    :ash_phoenix,
    :ash_postgres,
    :ash_rate_limiter,
    :ash,
    :reactor,
    :ecto,
    :ecto_sql,
    :phoenix
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Absinthe.Formatter, Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]
