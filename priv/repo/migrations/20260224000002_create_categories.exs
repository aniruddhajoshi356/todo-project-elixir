defmodule PlanoraLive.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:categories, [:user_id])
    create unique_index(:categories, [:name, :user_id])
  end
end
