import Config
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

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

# Signs the admin session tokens in the suite.
config :lumen_viae, :token_signing_secret, "test-only-token-signing-secret-for-lumen-viae-admin"

# Hashing an admin's password at production cost would make every signed-in
# test slow. Never set this anywhere but test.
config :bcrypt_elixir, log_rounds: 1

# Jobs are inserted but never run on their own: a test that wants one to
# run drains its queue (Oban.drain_queue/1), so nothing happens behind a
# test's back and every job runs inside the test's sandbox.
config :lumen_viae, Oban, testing: :manual

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

# The same for console sign-in, for the same reason. The throttle's own
# test passes its limits to the plug directly.
config :lumen_viae, :sign_in_per_ip, 1_000_000
config :lumen_viae, :sign_in_per_email, 1_000_000

# Every Divine Office fetch in the suite goes through Req.Test. A test
# that forgets to stub gets a loud "no stub" error instead of a quiet
# request to the real Divinum Officium site.
config :lumen_viae, :office, req_options: [plug: {Req.Test, LumenViae.Office.DivinumOfficium}]

# The suite's own two narration voices, fixed here so the tests of the
# voice mechanics do not move every time the production line-up in
# config.exs does. test/lumen_viae/rosary/voices_config_test.exs reads
# config.exs itself and checks the production line-up.
config :lumen_viae, :narration_voices, [
  %{
    slug: "female",
    name: "Female",
    description: "A gentle, emotive narrator",
    eleven_labs_voice_id: "Z3R5wn05IrDiVCyEkUrK",
    model_id: "eleven_v3",
    voice_settings: %{stability: 0.5, similarity_boost: 0.75},
    default: true
  },
  %{
    slug: "male",
    name: "Male",
    description: "A calm, measured narrator",
    eleven_labs_voice_id: "RTFg9niKcgGLDwa3RFlz",
    model_id: "eleven_multilingual_v2",
    voice_settings: %{stability: 0.5, similarity_boost: 0.75, style: 0.5},
    default: false
  }
]

# The System screen probes S3 and the Office engine when it mounts. In the
# suite they answer at once from here, so the screen's tests never wait on
# a fake client or a missing stub; test/lumen_viae/ops/probes_test.exs
# clears it to exercise the real probes. See LumenViae.Ops.Probes.
config :lumen_viae, :ops_probe_answers, %{
  s3: %{status: :ok, detail: "answered by config/test.exs"},
  office_engine: %{status: :ok, detail: "answered by config/test.exs"}
}

# Lets an Office test give itself cache keys of its own
# (LumenViae.Office.Cache.isolate/0), so async tests cannot see each
# other's entries.
config :lumen_viae, :isolate_office_cache, true
