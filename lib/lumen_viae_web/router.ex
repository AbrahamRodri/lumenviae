defmodule LumenViaeWeb.Router do
  use LumenViaeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug LumenViaeWeb.Plugs.CanonicalHost
    plug :fetch_session
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
    plug AshGraphql.Plug
  end

  # Only the completion write goes through this. The other API routes serve
  # content that is public on the site anyway, so turning a crawler away
  # from them protects nothing and mostly risks turning away a reader.
  pipeline :api_completions do
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

  # The site, the console's login and the console are three live sessions.
  # LiveView only navigates in place between routes of the same session, so
  # crossing from the site into the console always takes a full HTTP
  # request through RequireAdmin, and the console's own on_mount hook
  # refuses any socket that reaches it without an admin session. Without
  # the split, live navigation from a public page mounted the console over
  # the open socket and no plug ran at all. See LumenViaeWeb.UserAuth.
  scope "/", LumenViaeWeb do
    pipe_through :browser

    post "/admin/session", AdminSessionController, :create
    delete "/admin/session", AdminSessionController, :delete

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

  # Admin routes - protected by password authentication
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
    end
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

  # The one write the public API exposes, and so the one route that gets a
  # crawler check and a rate limit in front of it.
  scope "/api", LumenViaeWeb.API do
    pipe_through [:api, :api_completions]

    post "/completions", CompletionController, :create
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:lumen_viae, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LumenViaeWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    # An in-browser GraphQL explorer against /api/graphql, development only
    scope "/dev" do
      pipe_through :graphql

      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: Module.concat(["LumenViaeWeb.GraphqlSchema"]),
        interface: :simple
    end
  end

  defp put_private_cache_control(conn, _opts) do
    put_resp_header(conn, "cache-control", "private, no-store")
  end
end
