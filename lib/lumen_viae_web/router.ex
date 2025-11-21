defmodule LumenViaeWeb.Router do
  use LumenViaeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug LumenViaeWeb.Plugs.CanonicalHost
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LumenViaeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admin do
    plug LumenViaeWeb.Plugs.RequireAdmin
  end

  scope "/", LumenViaeWeb do
    pipe_through :browser

    # Home page - welcome and mystery categories
    live "/", Live.Home.Index

    # Prayer dashboard - focused mystery selection
    live "/dashboard", Live.Dashboard.Index

    # All 20 mysteries of the Rosary
    live "/mysteries", Live.Mysteries.Scripture

    # Methods of praying the Rosary (St. Louis de Montfort)
    live "/rosary-methods", Live.Home.Methods.Index

    # Feedback and feature requests
    live "/feedback", Live.Home.Feedback.Index

    # Admin login (public)
    live "/admin/login", Live.Admin.Login
    post "/admin/session", AdminSessionController, :create
    delete "/admin/session", AdminSessionController, :delete

    # Browse meditation sets by mystery category (public)
    live "/mysteries/:category", Live.Mysteries.CategoryList

    # Prayer experience for a specific meditation set
    live "/meditation-sets/:set_id/pray", Live.Pray.Index
  end

  # Admin routes - protected by password authentication
  scope "/admin", LumenViaeWeb do
    pipe_through [:browser, :admin]

    # Admin dashboard - landing page with navigation
    live "/", Live.Admin.Dashboard

    # Meditations management
    live "/meditations", Live.Meditations.List
    live "/meditations/new", Live.Meditations.New
    live "/meditations/:id/edit", Live.Meditations.Edit
    live "/meditations/import", Live.Admin.MeditationsImport.Import

    # Meditation Sets management
    live "/meditation-sets", Live.Meditations.Sets.List
    live "/meditation-sets/new", Live.Meditations.Sets.New
    live "/meditation-sets/:id/edit", Live.Meditations.Sets.Edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", LumenViaeWeb do
  #   pipe_through :api
  # end

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
  end
end
