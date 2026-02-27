defmodule PlanoraLive.Todos do
  import Ecto.Query
  alias PlanoraLive.Repo
  alias PlanoraLive.Todos.{Todo, Category, Tag}

  @page_size 5


  def list_todos(user_id, opts \\ []) do
    page   = Keyword.get(opts, :page, 1)
    search = Keyword.get(opts, :search, "")
    filter = Keyword.get(opts, :filter, "ALL")

    offset = (page - 1) * @page_size

    query =
      from t in Todo,
        where: t.user_id == ^user_id,
        order_by: [desc: t.inserted_at],
        preload: [:category, :tags]

    query =
      if filter != "ALL" do
        from t in query, where: t.status == ^filter
      else
        query
      end

    query =
      if search != "" do
        pattern = "%#{search}%"
        from t in query, where: ilike(t.title, ^pattern)
      else
        query
      end

    total = Repo.aggregate(query, :count, :id)
    todos = Repo.all(from q in query, limit: ^@page_size, offset: ^offset)

    %{
      todos: todos,
      total_items: total,
      total_pages: max(1, ceil(total / @page_size)),
      current_page: page
    }
  end

  def get_todo!(id, user_id) do
    Repo.get_by!(Todo, id: id, user_id: user_id)
    |> Repo.preload([:category, :tags])
  end

  def get_favorite_todos(user_id) do
    Repo.all(
      from t in Todo,
        where: t.user_id == ^user_id and t.is_favorite == true,
        order_by: [desc: t.inserted_at]
    )
  end

  def create_todo(attrs, tag_names \\ []) do
    result =
      %Todo{}
      |> Todo.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, todo} ->
        todo = attach_tags(todo, tag_names)
        {:ok, Repo.preload(todo, [:category, :tags], force: true)}

      error ->
        error
    end
  end

  def update_todo_title(todo, title) do
    todo
    |> Todo.changeset(%{title: title})
    |> Repo.update()
  end

  def update_todo_status(todo, status) do
    todo
    |> Todo.changeset(%{status: status})
    |> Repo.update()
  end

  def update_todo_favorite(todo, is_favorite) do
    todo
    |> Todo.changeset(%{is_favorite: is_favorite})
    |> Repo.update()
  end

  def update_todo_rating(todo, rating) do
    todo
    |> Todo.changeset(%{rating: rating})
    |> Repo.update()
  end

  def delete_todo(todo), do: Repo.delete(todo)

  def bulk_delete_todos(ids, user_id) do
    Repo.delete_all(
      from t in Todo,
        where: t.id in ^ids and t.user_id == ^user_id
    )
  end

  def remove_tag_from_todo(todo_id, tag_id, user_id) do
    todo = get_todo!(todo_id, user_id) |> Repo.preload(:tags)
    remaining_tags = Enum.reject(todo.tags, &(&1.id == tag_id))

    todo
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tags, remaining_tags)
    |> Repo.update()
  end


  def list_categories(user_id) do
    Repo.all(from c in Category, where: c.user_id == ^user_id, order_by: c.name)
  end

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end


  defp attach_tags(todo, []), do: todo

  defp attach_tags(todo, tag_names) do
    normalized =
      tag_names
      |> Enum.map(&String.downcase(String.trim(&1)))
      |> Enum.filter(&(&1 != ""))
      |> Enum.uniq()
      |> Enum.take(2)

    tags =
      Enum.map(normalized, fn name ->
        case Repo.get_by(Tag, tagname: name) do
          nil ->
            {:ok, tag} = %Tag{} |> Tag.changeset(%{tagname: name}) |> Repo.insert()
            tag

          tag ->
            tag
        end
      end)

    todo
    |> Repo.preload(:tags)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tags, tags)
    |> Repo.update!()
  end
end
