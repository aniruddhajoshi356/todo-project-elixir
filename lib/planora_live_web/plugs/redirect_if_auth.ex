defmodule PlanoraLiveWeb.Plugs.RedirectIfAuth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      conn
      |> redirect(to: "/todos")
      |> halt()
    else
      conn
    end
  end
end
