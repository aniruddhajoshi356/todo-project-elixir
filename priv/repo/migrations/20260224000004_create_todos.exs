defmodule PlanoraLive.Repo.Migrations.CreateTodos do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:todos) do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "in_progress"
      add :rating, :decimal, precision: 3, scale: 1, default: 0.0
      add :is_favorite, :boolean, default: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :nilify_all)

      timestamps()
    end

    create_if_not_exists index(:todos, [:user_id])
    create_if_not_exists index(:todos, [:category_id])
  end
end
