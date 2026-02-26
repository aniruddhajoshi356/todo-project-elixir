defmodule PlanoraLiveWeb.AuthLive do
  use PlanoraLiveWeb, :live_view

  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="auth-page">
      <%= if @live_action == :login do %>
        <.login_form flash={@flash} />
      <% else %>
        <.signup_form flash={@flash} />
      <% end %>
    </div>
    """
  end

  defp login_form(assigns) do
    ~H"""
    <div class="auth-container">
      <div class="auth-card">
        <div class="auth-logo">
          <div class="logo-icon">
            <img src={~p"/images/todo-app.png"} alt="Planora Logo" height="50" width="50" />
          </div>
          <h1 class="auth-brand">Planora</h1>
        </div>
        <h2 class="auth-title">Welcome back</h2>
        <p class="auth-subtitle">Sign in to your account to continue</p>

        <%= if @flash["error"] do %>
          <div class="auth-error">
            <span>⚠️</span> {@flash["error"]}
          </div>
        <% end %>

        <form method="post" action="/login" class="auth-form">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

          <div class="form-group">
            <label class="form-label" for="login-email">Email</label>
            <input
              type="email"
              id="login-email"
              name="email"
              class="form-input"
              placeholder="your@email.com"
              required
            />
          </div>

          <div class="form-group">
            <label class="form-label" for="login-password">Password</label>
            <div class="input-with-icon">
              <input
                type="password"
                id="login-password"
                name="password"
                class="form-input"
                placeholder="••••••••"
                required
              />
              <button
                type="button"
                class="eye-btn"
                phx-click={
                  JS.toggle_attribute({"type", "password", "text"}, to: "#login-password")
                  |> JS.toggle(to: "#login-eye-show")
                  |> JS.toggle(to: "#login-eye-hide")
                }
              >
                <i id="login-eye-hide" class="fa fa-eye-slash"></i>
                <i id="login-eye-show" class="fa fa-eye" style="display:none;"></i>
              </button>
            </div>
          </div>

          <button type="submit" class="auth-btn">Sign In</button>
        </form>

        <p class="auth-switch">
          Don't have an account? <a href="/signup" class="auth-link">Sign up</a>
        </p>
      </div>
    </div>
    """
  end

  defp signup_form(assigns) do
    ~H"""
    <div class="auth-container">
      <div class="auth-card">
        <div class="auth-logo">
          <div class="logo-icon">
            <img src={~p"/images/todo-app.png"} alt="Planora Logo" height="50" width="50" />
          </div>
          <h1 class="auth-brand">Planora</h1>
        </div>
        <h2 class="auth-title">Create account</h2>
        <p class="auth-subtitle">Start organising your tasks today</p>

        <%= if @flash["error"] do %>
          <div class="auth-error">
            <span>⚠️</span> {@flash["error"]}
          </div>
        <% end %>

        <form method="post" action="/signup" class="auth-form">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

          <div class="form-group">
            <label class="form-label" for="signup-username">Username</label>
            <input
              type="text"
              id="signup-username"
              name="username"
              class="form-input"
              placeholder="Your name"
              required
            />
          </div>

          <div class="form-group">
            <label class="form-label" for="signup-email">Email</label>
            <input
              type="email"
              id="signup-email"
              name="email"
              class="form-input"
              placeholder="your@email.com"
              required
            />
          </div>

          <div class="form-group">
            <label class="form-label" for="signup-password">Password</label>
            <div class="input-with-icon">
              <input
                type="password"
                id="signup-password"
                name="password"
                class="form-input"
                placeholder="Min 6 characters"
                required
              />
              <button
                type="button"
                class="eye-btn"
                phx-click={
                  JS.toggle_attribute({"type", "password", "text"}, to: "#signup-password")
                  |> JS.toggle(to: "#signup-eye-show")
                  |> JS.toggle(to: "#signup-eye-hide")
                }
              >
                <i id="signup-eye-hide" class="fa fa-eye-slash"></i>
                <i id="signup-eye-show" class="fa fa-eye" style="display:none;"></i>
              </button>
            </div>
          </div>

          <button type="submit" class="auth-btn">Sign Up</button>
        </form>

        <p class="auth-switch">
          Already have an account? <a href="/login" class="auth-link">Sign in</a>
        </p>
      </div>
    </div>
    """
  end
end
