# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ash_graphql, authorize_update_destroy_with_error?: true

# Errors name their fields as GraphQL spells them. See
# LumenViaeWeb.Graphql.ErrorHandler.
for domain <- [LumenViae.Rosary, LumenViae.Office] do
  config :lumen_viae, domain,
    graphql: [error_handler: {LumenViaeWeb.Graphql.ErrorHandler, :handle_error, []}]
end

config :ash,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true,
  redact_sensitive_values_in_errors?: true,
  # Count string length in codepoints, as Postgres does, so an attribute's
  # max_length: 255 means exactly what the varchar(255) column means.
  default_string_length_count: :codepoints

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :graphql,
        :postgres,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [:graphql, :resources, :policies, :authorization, :domain, :execution]
    ]
  ]

config :lumen_viae,
  ecto_repos: [LumenViae.Repo],
  ash_domains: [LumenViae.Office, LumenViae.Rosary],
  generators: [timestamp_type: :utc_datetime]

# Default narration pause inserted at each paragraph break when generating
# meditation audio (seconds; ElevenLabs caps break tags at 3s).
config :lumen_viae, :tts_paragraph_break_seconds, 1.2

# The narration voices, in the order clients list them. Every meditation
# with audio is narrated once per voice, stored under
# voices/<slug>/<filename> in the audio bucket. The first voice marked
# default: true is what the legacy `audio_url` fields and the website play.
#
# Each voice names the ElevenLabs model it is synthesized with and its
# voice settings. Eleven v3 and v4 take audio tags ([pause], [long pause])
# rather than SSML break tags for their pauses, and LumenViae.Audio.TtsText
# picks the syntax from the model, so the voices may sit on different models.
#
# A voice with `hidden: true` is kept - its files, its rows and its slug
# still resolve for tooling - but is never offered to a client; a request
# naming it is served by its `replaced_by` voice instead. A voice with
# `rosary_audio_from` has not recorded the spoken Rosary itself (yet): each
# clip kind named there is served from that other voice's recordings.
# See LumenViae.Rosary.Voices and LumenViae.Rosary.PrayerAudio.
config :lumen_viae, :narration_voices, [
  # Frederick Surrey, the male narrator since 2026-09-29. Every public
  # meditation was recorded from a hand-tagged script
  # (priv/narration_scripts/frederick, generate_frederick.py); the app's own
  # regeneration sends plain text, without those direction tags. His spoken
  # Rosary (prayers, announcements and verses) was recorded on 2026-09-29;
  # the Prayer Book, which he has not recorded yet, is Arabella's.
  %{
    slug: "frederick",
    name: "Male",
    description: "A warm, reverent narrator",
    eleven_labs_voice_id: "j9jfwdrw7BRfcR43Qohk",
    model_id: "eleven_v4",
    voice_settings: %{stability: 0.5, similarity_boost: 0.75},
    rosary_audio_from: %{book: "female"},
    default: true
  },
  # Arabella. Her meditations whose text changed in the 2026-09-28/29 review
  # were re-recorded on Eleven v4 by the same script; the rest are Eleven v3.
  # Her whole spoken Rosary and Prayer Book (360 clips) were re-recorded on
  # v4 on 2026-09-29, which is why the model can be eleven_v4 here: a
  # spoken-Rosary file's name hashes the voice's model and settings
  # (PrayerAudio.filename/2), so the v3 files stay in the bucket unused.
  %{
    slug: "female",
    name: "Female",
    description: "A gentle, emotive narrator",
    eleven_labs_voice_id: "Z3R5wn05IrDiVCyEkUrK",
    model_id: "eleven_v4",
    voice_settings: %{stability: 0.5, similarity_boost: 0.75},
    default: false
  },
  # Marc Aurele, the original narrator. Retired from the pickers in favor of
  # Frederick; his recordings stay.
  %{
    slug: "male",
    name: "Male (original)",
    description: "A calm, measured narrator",
    eleven_labs_voice_id: "RTFg9niKcgGLDwa3RFlz",
    model_id: "eleven_multilingual_v2",
    voice_settings: %{stability: 0.5, similarity_boost: 0.75, style: 0.5},
    hidden: true,
    replaced_by: "frederick",
    default: false
  }
]

# Turning an address into a rough place for the completion analytics.
# Off unless a runtime config says otherwise, so a lookup is something
# production opts into rather than something every laptop does by default.
# See LumenViae.Services.Geolocation.
config :lumen_viae, :geolocation,
  enabled: false,
  provider: :ipapi_co

# Where the Divine Office texts come from: a Divinum Officium instance.
# The public site by default; production can point at a self-hosted copy
# of the engine through DIVINUM_OFFICIUM_BASE_URL without a code change.
# See LumenViae.Office.DivinumOfficium.
config :lumen_viae, :office, base_url: "https://www.divinumofficium.com"

# Configures the endpoint
config :lumen_viae, LumenViaeWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LumenViaeWeb.ErrorHTML, json: LumenViaeWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LumenViae.PubSub,
  live_view: [signing_salt: "T9cze/la"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :lumen_viae, LumenViae.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.28.2",
  lumen_viae: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  lumen_viae: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# ExAws talks to S3 over Req, the client the app already uses for
# ElevenLabs and Divinum Officium. Its default, hackney, crashed against real
# S3 at hackney 4: ex_aws 2.7's adapter does not match the 3-tuple hackney 4
# returns for a HEAD, so every object check raised a CaseClauseError. The
# credentials and region stay in runtime.exs.
config :ex_aws, http_client: ExAws.Request.Req

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
