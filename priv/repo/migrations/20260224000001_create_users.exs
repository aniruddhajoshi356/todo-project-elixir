defmodule PlanoraLive.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:users) do
      add :username, :string, null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false

      timestamps()
    end

    create_if_not_exists unique_index(:users, [:email])
  end
end
