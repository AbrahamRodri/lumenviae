defmodule LumenViaeWeb.Router do
  use LumenViaeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LumenViaeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LumenViaeWeb do
    pipe_through :browser

    # Rosary home - lists mystery categories (Joyful, Sorrowful, Glorious)
    live "/", Live.Rosary.List

    # Admin dashboard for managing meditations and sets
    live "/admin", Live.Admin.Dashboard

    # Lists meditation sets for a specific mystery category
    live "/mysteries/:category", Live.MysterySet.List

    # Prayer experience for a specific meditation set
    live "/meditation-sets/:set_id/pray", Live.MeditationSet.Pray
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
