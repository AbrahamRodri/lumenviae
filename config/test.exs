import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :lumen_viae, LumenViae.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "lumen_viae_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :lumen_viae, LumenViaeWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "vxLRHzmYy9gzBM+pjpcs/W7PGLpWi/dVATjUqoieR+Xo5zJFYl9VaS7tYI6qKRGp",
  server: false

# In test we don't send emails
config :lumen_viae, LumenViae.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# The whole suite connects from 127.0.0.1, so a realistic per-address
# completion limit would be spent collectively by unrelated tests and the
# failures would land wherever the seed happened to put them. The tests that
# actually exercise the limit set their own.
config :lumen_viae, :completions_per_hour, 1_000_000

# Every Divine Office fetch in the suite goes through Req.Test. A test
# that forgets to stub gets a loud "no stub" error instead of a quiet
# request to the real Divinum Officium site.
config :lumen_viae, :office, req_options: [plug: {Req.Test, LumenViae.Office.DivinumOfficium}]
