defmodule PlanoraLive.Todos.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tags" do
    field :tagname, :string

    many_to_many :todos, PlanoraLive.Todos.Todo, join_through: "todo_tags"

    timestamps()
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:tagname])
    |> validate_required([:tagname])
    |> unique_constraint(:tagname)
  end
end
