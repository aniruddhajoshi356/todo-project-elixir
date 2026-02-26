defmodule PlanoraLive.Repo.Migrations.CreateTodoTags do
  use Ecto.Migration

  def change do
    create table(:todo_tags, primary_key: false) do
      add :todo_id, references(:todos, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:todo_tags, [:todo_id, :tag_id])
    create index(:todo_tags, [:tag_id])
  end
end
