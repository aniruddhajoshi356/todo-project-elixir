defmodule PlanoraLiveWeb.PageController do
  use PlanoraLiveWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
