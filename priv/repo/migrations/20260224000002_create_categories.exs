defmodule PlanoraLive.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:categories) do
      add :name, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create_if_not_exists index(:categories, [:user_id])
    create_if_not_exists unique_index(:categories, [:name, :user_id])
  end
end
