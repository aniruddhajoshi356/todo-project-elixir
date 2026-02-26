defmodule PlanoraLiveWeb.Router do
  use PlanoraLiveWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PlanoraLiveWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :require_auth do
    plug PlanoraLiveWeb.Plugs.RequireAuth
  end

  pipeline :redirect_if_auth do
    plug PlanoraLiveWeb.Plugs.RedirectIfAuth
  end

  scope "/", PlanoraLiveWeb do
    pipe_through [:browser, :redirect_if_auth]

    live "/",       AuthLive, :login
    live "/login",  AuthLive, :login
    live "/signup", AuthLive, :signup
  end

  scope "/", PlanoraLiveWeb do
    pipe_through :browser

    post   "/login",  SessionController, :login
    post   "/signup", SessionController, :signup
    delete "/logout", SessionController, :logout
  end

  scope "/", PlanoraLiveWeb do
    pipe_through [:browser, :require_auth]

    live "/todos", TodoLive, :index
  end

  # LiveDashboard in development
  if Application.compile_env(:planora_live, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: PlanoraLiveWeb.Telemetry
    end
  end
end
