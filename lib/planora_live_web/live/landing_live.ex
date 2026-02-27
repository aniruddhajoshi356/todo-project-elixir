defmodule PlanoraLiveWeb.LandingLive do
  use PlanoraLiveWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="lp">
      <nav class="lp-nav">
        <div class="lp-brand">
          <img src={~p"/images/todo-app.png"} alt="Planora" width="28" height="28" />
          <span>Planora</span>
        </div>
        <a href="/login" class="lp-signin">Sign in</a>
      </nav>

      <main class="lp-hero">
        <p class="lp-eyebrow">Task management, simplified</p>
        <h1 class="lp-headline">Stay on top of<br /><span class="lp-accent">everything.</span></h1>
        <p class="lp-desc">
          Capture tasks, set priorities, and track progress — all in one quiet, focused place.
        </p>
        <div class="lp-actions">
          <a href="/signup" class="lp-btn-primary">Get started free</a>
          <a href="/login" class="lp-btn-ghost">Sign in</a>
        </div>
        <div class="lp-chips">
          <div class="lp-chip"><i class="fa fa-tags"></i> Smart categories</div>
          <div class="lp-chip"><i class="fa fa-star"></i> Priority ratings</div>
          <div class="lp-chip"><i class="fa fa-bolt"></i> Real-time updates</div>
        </div>
      </main>
    </div>
    """
  end
end
