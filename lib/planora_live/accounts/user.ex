defmodule PlanoraLive.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string

    has_many :todos, PlanoraLive.Todos.Todo
    has_many :categories, PlanoraLive.Todos.Category

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password])
    |> validate_required([:username, :email, :password])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 6)
    |> unique_constraint(:email)
    |> hash_password()
  end

  defp hash_password(changeset) do
    if changeset.valid? do
      put_change(
        changeset,
        :password_hash,
        Bcrypt.hash_pwd_salt(get_change(changeset, :password))
      )
    else
      changeset
    end
  end
end
