defmodule PlanoraLive.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:tags) do
      add :tagname, :string, null: false

      timestamps()
    end

    create_if_not_exists unique_index(:tags, [:tagname])
  end
end
