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

  pipeline :prayer_browser do
    plug :accepts, ["html"]
    plug LumenViaeWeb.Plugs.CanonicalHost
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LumenViaeWeb.Layouts, :prayer_root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LumenViaeWeb do
    pipe_through :browser

    # Home page - welcome and mystery categories
    live "/", Live.Home.Index

    # All 20 mysteries of the Rosary
    live "/mysteries", Live.Mysteries.Scripture

    # Methods of praying the Rosary (St. Louis de Montfort)
    live "/rosary-methods", Live.Home.Methods.Index

    # Feedback and feature requests
    live "/feedback", Live.Home.Feedback.Index

    # Admin dashboard - landing page with navigation
    live "/admin", Live.Admin.Dashboard

    # Meditations management (admin access)
    live "/admin/meditations", Live.Meditations.List
    live "/admin/meditations/new", Live.Meditations.New
    live "/admin/meditations/:id/edit", Live.Meditations.Edit
    live "/admin/meditations/import", Live.Admin.MeditationsImport.Import

    # Meditation Sets management (admin access)
    live "/admin/meditation-sets", Live.Meditations.Sets.List
    live "/admin/meditation-sets/new", Live.Meditations.Sets.New
    live "/admin/meditation-sets/:id/edit", Live.Meditations.Sets.Edit

    # Browse meditation sets by mystery category (public)
    live "/mysteries/:category", Live.Mysteries.CategoryList

  end

  scope "/", LumenViaeWeb do
    pipe_through :prayer_browser

    # Prayer experience for a specific meditation set
    live "/meditation-sets/:set_id/pray", Live.Pray.Index
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
