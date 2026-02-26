defmodule PlanoraLive.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :tagname, :string, null: false

      timestamps()
    end

    create unique_index(:tags, [:tagname])
  end
end
