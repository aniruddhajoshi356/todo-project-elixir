defmodule PlanoraLiveWeb.SessionController do
  use PlanoraLiveWeb, :controller

  alias PlanoraLive.Accounts

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome back, #{user.username}!")
        |> redirect(to: ~p"/todos")

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: ~p"/login")
    end
  end

  def signup(conn, %{"username" => username, "email" => email, "password" => password}) do
    case Accounts.register_user(%{username: username, email: email, password: password}) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Account created! Welcome, #{user.username}!")
        |> redirect(to: ~p"/todos")

      {:error, changeset} ->
        error =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end)
          |> Enum.join(", ")

        conn
        |> put_flash(:error, error)
        |> redirect(to: ~p"/signup")
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/login")
  end
end
