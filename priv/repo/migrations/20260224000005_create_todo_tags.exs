defmodule PlanoraLive.Repo.Migrations.CreateTodoTags do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:todo_tags, primary_key: false) do
      add :todo_id, references(:todos, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create_if_not_exists unique_index(:todo_tags, [:todo_id, :tag_id])
    create_if_not_exists index(:todo_tags, [:tag_id])
  end
end
