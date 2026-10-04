defmodule LumenViaeWeb.Router do
  use LumenViaeWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAdmin.Router
  import Oban.Web.Router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug LumenViaeWeb.Plugs.CanonicalHost
    plug :fetch_session
    # Puts the signed-in admin, if any, in `current_admin`: the session's
    # token is verified and must still be stored and unrevoked.
    plug :load_from_session
    # Must follow :fetch_session, and must come before any LiveView that
    # reads the address out of the session. See Plugs.PutClientIP.
    plug LumenViaeWeb.Plugs.PutClientIP
    plug :fetch_live_flash
    plug :put_root_layout, html: {LumenViaeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # The GraphQL API. Off the browser pipeline like the rest of /api: no
  # session, no CSRF token, and no canonical-host redirect, which would turn
  # a client's POST into a GET. Every response is private and uncacheable,
  # because a query may select presigned audio URLs. See docs/GRAPHQL.md.
  pipeline :graphql do
    plug :accepts, ["json"]
    plug :put_private_cache_control
    plug LumenViaeWeb.Graphql.PutRequestContext
    plug AshGraphql.Plug
  end

  # The versioned JSON:API at /api/v2. Sessionless like the rest of /api,
  # and private and uncacheable like GraphQL, because a request may select
  # presigned audio URLs. PutRequestContext hands the actions the caller's
  # address from the connection, which the completion write stamps. No
  # guard plug: the completion's checks belong on its action, where they
  # cover every API at once. See docs/JSON_API.md.
  pipeline :json_api do
    plug :put_private_cache_control
    plug LumenViaeWeb.JsonApi.QueryParams
    plug LumenViaeWeb.Graphql.PutRequestContext
  end

  # Only the completion write goes through this. The other API routes serve
  # content that is public on the site anyway, so turning a crawler away
  # from them protects nothing and mostly risks turning away a reader.
  pipeline :api_completions do
    plug LumenViaeWeb.Plugs.RetryAfter, window: :completion
    plug LumenViaeWeb.Plugs.GuardCompletions
  end

  # The console is a tool, not a page of the site: it gets a bare layout with
  # no public header and no footer, so the full height belongs to the work.
  pipeline :admin_layout do
    plug :put_root_layout, html: {LumenViaeWeb.Layouts, :root_admin}
  end

  pipeline :admin do
    plug LumenViaeWeb.Plugs.RequireAdmin
  end

  # In front of the password strategy, so a throttled attempt never reaches
  # bcrypt. See Plugs.ThrottleSignIn.
  pipeline :sign_in do
    plug LumenViaeWeb.Plugs.ThrottleSignIn
  end

  # The site, the console's login and the console are three live sessions.
  # LiveView only navigates in place between routes of the same session, so
  # crossing from the site into the console always takes a full HTTP
  # request through RequireAdmin, and the console's own on_mount hook
  # refuses any socket that reaches it without a signed-in admin. Without
  # the split, live navigation from a public page mounted the console over
  # the open socket and no plug ran at all. See LumenViaeWeb.UserAuth.
  # The sign-in form posts to the password strategy's route under here,
  # /admin/auth/admin/password/sign_in; AshAuthentication checks it and
  # hands the outcome to AuthController. CSRF-checked like any form, and
  # throttled before the password is checked.
  scope "/", LumenViaeWeb do
    pipe_through [:browser, :sign_in]

    auth_routes(AuthController, LumenViae.Accounts.Admin, path: "/admin/auth")
  end

  scope "/", LumenViaeWeb do
    pipe_through :browser

    delete "/admin/session", AuthController, :sign_out

    live_session :public do
      # Home page - welcome and mystery categories
      live "/", Live.Home.Index

      # iOS app landing page
      live "/app", Live.Home.App.Index

      # Prayer dashboard - focused mystery selection
      live "/dashboard", Live.Dashboard.Index

      # All 20 mysteries of the Rosary
      live "/mysteries", Live.Mysteries.Scripture

      # How to pray the Rosary, with the methods of St. Louis de Montfort
      live "/rosary-methods", Live.Home.Methods.Index

      # True Devotion to Mary (St. Louis de Montfort)
      live "/true-devotion", Live.Home.TrueDevotion.Index

      # St. Carlo Acutis - patron of Lumen Viae
      live "/saint-carlo", Live.Home.SaintCarlo.Index

      # Feedback and feature requests
      live "/feedback", Live.Home.Feedback.Index

      # Privacy policy (for iOS App Store listing)
      live "/privacy-policy", Live.PrivacyPolicy.Index

      # Browse meditation sets by mystery category (public)
      live "/mysteries/:category", Live.Mysteries.CategoryList

      # Prayer experience for a specific meditation set
      live "/meditation-sets/:set_id/pray", Live.Pray.Index
    end
  end

  # Admin login: the console's layout, but no admin session required yet.
  scope "/", LumenViaeWeb do
    pipe_through [:browser, :admin_layout]

    live_session :admin_login do
      live "/admin/login", Live.Admin.Login
    end
  end

  # Admin routes - a signed-in admin only
  scope "/admin", LumenViaeWeb do
    pipe_through [:browser, :admin_layout, :admin]

    live_session :admin, on_mount: [{LumenViaeWeb.UserAuth, :require_admin}] do
      # Admin dashboard - landing page with navigation
      live "/", Live.Admin.Dashboard

      # Meditations management
      live "/meditations", Live.Meditations.List
      live "/meditations/new", Live.Meditations.New
      live "/meditations/:id/edit", Live.Meditations.Edit
      live "/meditations/import", Live.Admin.MeditationsImport.Import

      # The spoken Rosary's recordings: coverage and a player for each clip
      live "/rosary-audio", Live.Admin.RosaryAudio

      # The running app: release, database, queues, schedule, third parties
      live "/system", Live.Admin.System

      # Who may sign in, and their passwords
      live "/admins", Live.Admin.Admins

      # Meditation Sets management
      live "/meditation-sets", Live.Meditations.Sets.List
      live "/meditation-sets/new", Live.Meditations.Sets.New
      live "/meditation-sets/:id/edit", Live.Meditations.Sets.Edit

      live "/authors", Live.Meditations.Authors.List
      live "/authors/new", Live.Meditations.Authors.New
      live "/authors/:id/edit", Live.Meditations.Authors.Edit

      # Mysteries management
      live "/mysteries", Live.Mysteries.List
      live "/mysteries/new", Live.Mysteries.New
      live "/mysteries/:id/edit", Live.Mysteries.Edit
      live "/mysteries/cards/:slug", Live.Mysteries.Card
    end
  end

  # AshAdmin: a generic browser over every Ash resource, for the cases the
  # console has no screen for, and Oban Web, the background jobs. Each
  # brings its own look and its own live_session, so each gets the
  # console's guard twice over: RequireAdmin on the HTTP request, and the
  # :require_admin hook on every socket mount. Unaliased scope, because the
  # macros name the libraries' own LiveViews.
  scope "/admin" do
    pipe_through [:browser, :admin]

    ash_admin("/data",
      live_session_name: :ash_admin,
      on_mount: [
        {LumenViaeWeb.UserAuth, :require_admin},
        {LumenViaeWeb.AshAdminActor, :lock_authorization}
      ]
    )

    oban_dashboard "/jobs",
      as: :oban_jobs,
      on_mount: [{LumenViaeWeb.UserAuth, :require_admin}],
      resolver: LumenViaeWeb.ObanResolver

    # Phoenix LiveDashboard: the VM's processes, ETS tables, ports and the
    # metrics in LumenViaeWeb.Telemetry, behind the console's guard like
    # Oban Web. It can kill a process, so it is an admin's tool only. No
    # env_keys: the environment holds every secret the app has. ecto_repos
    # adds the Ecto Stats page (ecto_psql_extras): bloat, index use, locks,
    # long-running queries.
    live_dashboard "/live",
      live_session_name: :live_dashboard,
      on_mount: [{LumenViaeWeb.UserAuth, :require_admin}],
      metrics: LumenViaeWeb.Telemetry,
      ecto_repos: [LumenViae.Repo]
  end

  # Liveness and the database, for whatever watches the app. Off the
  # browser pipeline (no session, no canonical-host redirect, which a check
  # against a machine's own address would trip) and out of the request log,
  # which a check every few seconds would fill. See HealthController.
  scope "/", LumenViaeWeb do
    pipe_through :api

    get "/healthz", HealthController, :show, log: false
  end

  # JSON API for iOS app
  scope "/api", LumenViaeWeb.API do
    pipe_through :api

    # Meditation Sets
    get "/meditation-sets", MeditationSetController, :index
    get "/meditation-sets/:id", MeditationSetController, :show

    # Meditations - a fresh narration URL for one meditation (in one voice,
    # ?voice=slug), so a client holding an expired one does not have to
    # refetch its whole set
    get "/meditations/:id/audio", MeditationController, :audio

    # The narration voices a meditation can be heard in
    get "/voices", VoiceController, :index

    # Mysteries
    get "/mysteries", MysteryController, :index

    # Prayers - the consecration chants, withdrawn for want of a licence.
    # Kept only so installed builds get a 410 rather than a bare 404; it
    # signs nothing (see PrayerController)
    get "/prayers/:id/audio", PrayerController, :audio

    # The spoken Rosary: every prayer, announcement and scripture verse
    # recorded in one voice (?voice=slug), as one manifest of signed URLs
    get "/rosary/audio", RosaryAudioController, :show

    # The Divine Office (pre-Vatican II breviary), assembled by a Divinum
    # Officium instance and served as data. The two fixed segments must
    # stay above "/office/:date", which would otherwise swallow them.
    get "/office/versions", OfficeController, :versions
    get "/office/calendar/:year/:month", OfficeController, :calendar
    get "/office/:date", OfficeController, :day
    get "/office/:date/:hour", OfficeController, :hour
  end

  scope "/api" do
    pipe_through :graphql

    # Module.concat keeps the router from depending on the schema at
    # compile time, so changing a resource does not recompile the router.
    # See the "Compile Times" guide in the AshGraphql docs.
    forward "/graphql", Absinthe.Plug,
      schema: Module.concat(["LumenViaeWeb.GraphqlSchema"]),
      pipeline: {LumenViaeWeb.Graphql.Pipeline, :pipeline},
      analyze_complexity: true,
      max_complexity: 500
  end

  # The OpenAPI document: the committed file, served as it is. See
  # LumenViaeWeb.JsonApi.Document.
  scope "/api/v2" do
    get "/open_api", LumenViaeWeb.JsonApi.Document, []
  end

  # Last of the /api/v2 routes: the forward takes everything under it.
  # Module.concat for the reason given at /api/graphql above.
  scope "/api/v2" do
    pipe_through :json_api

    forward "/", Module.concat(["LumenViaeWeb.JsonApiRouter"])
  end

  # The one write the public API exposes, and so the one route that gets a
  # crawler check and a rate limit in front of it.
  scope "/api", LumenViaeWeb.API do
    pipe_through [:api, :api_completions]

    post "/completions", CompletionController, :create
  end

  # The Swoosh mailbox preview in development. LiveDashboard, which used to
  # live here too, is at /admin/live in every environment.
  if Application.compile_env(:lumen_viae, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    # An in-browser GraphQL explorer against /api/graphql, development only
    scope "/dev" do
      pipe_through :graphql

      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: Module.concat(["LumenViaeWeb.GraphqlSchema"]),
        interface: :simple
    end

    # Swagger UI over /api/v2's OpenAPI document, development only: it loads
    # its script from a CDN, which has no business running on the console's
    # origin in production. The document itself is /api/v2/open_api.
    scope "/dev" do
      get "/api-docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/v2/open_api"
    end
  end

  defp put_private_cache_control(conn, _opts) do
    put_resp_header(conn, "cache-control", "private, no-store")
  end
end
