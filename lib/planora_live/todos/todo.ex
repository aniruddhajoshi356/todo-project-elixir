defmodule PlanoraLive.Todos.Todo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "todos" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "in_progress"
    field :rating, :decimal, default: Decimal.new("0.0")
    field :is_favorite, :boolean, default: false

    belongs_to :user, PlanoraLive.Accounts.User
    belongs_to :category, PlanoraLive.Todos.Category
    many_to_many :tags, PlanoraLive.Todos.Tag, join_through: "todo_tags", on_replace: :delete

    timestamps()
  end

  @allowed_statuses ~w(in_progress on-hold completed)

  def changeset(todo, attrs) do
    todo
    |> cast(attrs, [:title, :description, :status, :rating, :is_favorite, :user_id, :category_id])
    |> validate_required([:title, :description, :user_id])
    |> validate_length(:title, min: 1)
    |> validate_inclusion(:status, @allowed_statuses)
    |> validate_number(:rating, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
  end
end
