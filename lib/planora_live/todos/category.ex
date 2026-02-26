defmodule PlanoraLive.Todos.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field :name, :string

    belongs_to :user, PlanoraLive.Accounts.User
    has_many :todos, PlanoraLive.Todos.Todo

    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1)
    |> unique_constraint([:name, :user_id])
  end
end
