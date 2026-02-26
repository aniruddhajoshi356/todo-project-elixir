defmodule PlanoraLiveWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      conn
    else
      conn
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
