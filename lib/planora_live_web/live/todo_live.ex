defmodule PlanoraLiveWeb.TodoLive do
  use PlanoraLiveWeb, :live_view

  alias PlanoraLive.{Accounts, Todos}

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]
    user_name = session["user_name"]
    user = Accounts.get_user!(user_id)

    categories = Todos.list_categories(user_id)
    result = Todos.list_todos(user_id)

    {:ok,
     assign(socket,
       user: user,
       user_name: user_name,
       todos: result.todos,
       total_pages: result.total_pages,
       current_page: result.current_page,
       total_items: result.total_items,
       filter: "ALL",
       search: "",
       selected_ids: [],
       categories: categories,
       # form state — only category_id needs server tracking (auto-selected after creation)
       # form_key forces DOM recreation on success, clearing all uncontrolled inputs
       form_category_id: "",
       form_key: 0,
       # modals
       show_delete_modal: false,
       todo_to_delete: nil,
       show_bulk_modal: false,
       show_edit_modal: false,
       todo_to_edit: nil,
       edit_title: "",
       show_favorites_modal: false,
       favorite_todos: [],
       show_new_category_modal: false,
       new_category_name: "",
       # toast
       toast: nil,
       toast_type: "success"
     )}
  end

  # ─── SEARCH (debounced via JS hook) ─────────────────────────────────────────

  @impl true
  def handle_event("search", %{"value" => value}, socket) do
    socket = assign(socket, search: value, current_page: 1)
    {:noreply, reload_todos(socket)}
  end

  # ─── FILTER ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("filter", %{"value" => value}, socket) do
    socket = assign(socket, filter: value, current_page: 1, selected_ids: [])
    {:noreply, reload_todos(socket)}
  end

  # ─── CATEGORY SELECT ────────────────────────────────────────────────────────
  # Only the <select> uses phx-change. Text inputs are uncontrolled.
  # phx-submit on the <form> captures live DOM values at submit time.

  @impl true
  def handle_event("category_changed", %{"category_id" => "__new__"}, socket) do
    {:noreply, assign(socket, show_new_category_modal: true, new_category_name: "")}
  end

  @impl true
  def handle_event("category_changed", %{"category_id" => cat_id}, socket) do
    {:noreply, assign(socket, form_category_id: cat_id)}
  end

  # ─── ADD TODO (values from phx-submit params = live DOM, not stale assigns) ─

  @impl true
  def handle_event("add_todo", params, socket) do
    title = String.trim(params["title"] || "")
    desc = String.trim(params["description"] || "")
    cat_id = params["category_id"] || ""
    tags_str = String.trim(params["tags"] || "")

    tag_arr =
      tags_str
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    cond do
      title == "" ->
        {:noreply, show_toast(socket, "Title is required", "error")}

      desc == "" ->
        {:noreply, show_toast(socket, "Description is required", "error")}

      cat_id == "" or cat_id == "__new__" ->
        {:noreply, show_toast(socket, "Please select a valid category", "error")}

      tags_str == "" ->
        {:noreply, show_toast(socket, "At least one tag is required", "error")}

      length(tag_arr) > 2 ->
        {:noreply, show_toast(socket, "Maximum 2 tags allowed per todo", "error")}

      true ->
        attrs = %{
          title: title,
          description: desc,
          category_id: cat_id,
          user_id: socket.assigns.user.id,
          status: "in_progress"
        }

        try do
          case Todos.create_todo(attrs, tag_arr) do
            {:ok, _todo} ->
              socket =
                socket
                |> assign(
                  # Incrementing form_key changes the form id → LiveView destroys
                  # old form DOM and creates fresh one, clearing all uncontrolled inputs
                  form_key: socket.assigns.form_key + 1,
                  form_category_id: "",
                  current_page: 1
                )
                |> reload_todos()
                |> show_toast("Todo created! ✨", "success")

              {:noreply, socket}

            {:error, changeset} ->
              {:noreply, show_toast(socket, format_changeset_error(changeset), "error")}
          end
        rescue
          e in Ecto.ConstraintError ->
            {:noreply, show_toast(socket, "Database error: #{e.message}", "error")}

          e ->
            {:noreply, show_toast(socket, "Unexpected error: #{Exception.message(e)}", "error")}
        end
    end
  end

  # ─── STATUS CHANGE ──────────────────────────────────────────────────────────

  @impl true
  def handle_event("status_change", params, socket) do
    # params come from a mini phx-change form: {"status" => "...", "todo_id" => "..."}
    id = params["todo_id"] || params["id"] || ""
    status = params["status"] || ""

    if id == "" or status == "" do
      {:noreply, socket}
    else
      try do
        todo = Todos.get_todo!(String.to_integer(id), socket.assigns.user.id)

        case Todos.update_todo_status(todo, status) do
          {:ok, _} ->
            label = status |> String.replace("_", " ") |> String.capitalize()
            {:noreply, socket |> reload_todos() |> show_toast("Status → #{label}", "success")}

          {:error, changeset} ->
            {:noreply, show_toast(socket, format_changeset_error(changeset), "error")}
        end
      rescue
        Ecto.NoResultsError ->
          {:noreply, show_toast(socket, "Todo not found", "error")}

        e ->
          {:noreply, show_toast(socket, "Update failed: #{Exception.message(e)}", "error")}
      end
    end
  end

  # ─── TOGGLE FAVORITE ────────────────────────────────────────────────────────

  @impl true
  def handle_event("toggle_favorite", %{"id" => id}, socket) do
    # Fetch current todo and toggle server-side — avoids client-side boolean-string conversion bugs
    # (Elixir's ! treats 0, 1, "false" etc. as truthy, which was always sending "false")
    try do
      todo = Todos.get_todo!(String.to_integer(id), socket.assigns.user.id)
      # negate the REAL current DB value
      new_fav = !todo.is_favorite

      case Todos.update_todo_favorite(todo, new_fav) do
        {:ok, _} ->
          {msg, type} =
            if new_fav,
              do: {"Todo Bookmarked Successfully!", "success"},
              else: {"Todo Removed from favorites Successfully!", "success"}

          {:noreply, socket |> reload_todos() |> show_toast(msg, type)}

        {:error, changeset} ->
          {:noreply, show_toast(socket, format_changeset_error(changeset), "error")}
      end
    rescue
      e -> {:noreply, show_toast(socket, "Failed to update: #{Exception.message(e)}", "error")}
    end
  end

  # ─── RATING ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("rate_todo", %{"id" => id, "rating" => rating_str}, socket) do
    try do
      todo = Todos.get_todo!(String.to_integer(id), socket.assigns.user.id)
      rating = String.to_float(rating_str)

      case Todos.update_todo_rating(todo, rating) do
        {:ok, _} ->
          formatted = :erlang.float_to_binary(rating, decimals: 1)

          {:noreply,
           socket |> reload_todos() |> show_toast("★ Rating set to #{formatted}/5.0", "success")}

        {:error, changeset} ->
          {:noreply, show_toast(socket, format_changeset_error(changeset), "error")}
      end
    rescue
      e ->
        {:noreply,
         show_toast(socket, "Failed to update rating: #{Exception.message(e)}", "error")}
    end
  end

  # ─── REMOVE TAG ─────────────────────────────────────────────────────────────

  @impl true
  def handle_event("remove_tag", %{"todo_id" => todo_id, "tag_id" => tag_id}, socket) do
    try do
      case Todos.remove_tag_from_todo(
             String.to_integer(todo_id),
             String.to_integer(tag_id),
             socket.assigns.user.id
           ) do
        {:ok, _} ->
          {:noreply, socket |> reload_todos() |> show_toast("Tag removed", "success")}

        {:error, changeset} ->
          {:noreply, show_toast(socket, format_changeset_error(changeset), "error")}
      end
    rescue
      e ->
        {:noreply, show_toast(socket, "Failed to remove tag: #{Exception.message(e)}", "error")}
    end
  end

  # ─── SELECT / DESELECT ──────────────────────────────────────────────────────

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    id = String.to_integer(id)
    ids = socket.assigns.selected_ids

    new_ids =
      if id in ids, do: List.delete(ids, id), else: [id | ids]

    {:noreply, assign(socket, selected_ids: new_ids)}
  end

  @impl true
  def handle_event("select_all", _params, socket) do
    todos = socket.assigns.todos

    new_ids =
      if length(socket.assigns.selected_ids) == length(todos) do
        []
      else
        Enum.map(todos, & &1.id)
      end

    {:noreply, assign(socket, selected_ids: new_ids)}
  end

  # ─── DELETE MODAL ───────────────────────────────────────────────────────────

  @impl true
  def handle_event("open_delete_modal", %{"id" => id}, socket) do
    todo = Todos.get_todo!(String.to_integer(id), socket.assigns.user.id)
    {:noreply, assign(socket, show_delete_modal: true, todo_to_delete: todo)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: false, todo_to_delete: nil)}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    try do
      Todos.delete_todo(socket.assigns.todo_to_delete)

      socket =
        socket
        |> assign(show_delete_modal: false, todo_to_delete: nil)
        |> reload_todos()
        |> show_toast("Todo deleted", "success")

      {:noreply, socket}
    rescue
      e -> {:noreply, show_toast(socket, "Failed to delete: #{Exception.message(e)}", "error")}
    end
  end

  # ─── BULK DELETE MODAL ──────────────────────────────────────────────────────

  @impl true
  def handle_event("open_bulk_modal", _params, socket) do
    if length(socket.assigns.selected_ids) == 0 do
      {:noreply, socket}
    else
      {:noreply, assign(socket, show_bulk_modal: true)}
    end
  end

  @impl true
  def handle_event("cancel_bulk", _params, socket) do
    {:noreply, assign(socket, show_bulk_modal: false, selected_ids: [])}
  end

  @impl true
  def handle_event("confirm_bulk_delete", _params, socket) do
    try do
      {count, _} = Todos.bulk_delete_todos(socket.assigns.selected_ids, socket.assigns.user.id)
      total_todos = length(socket.assigns.todos)

      message =
        if count == total_todos do
          "All todos deleted"
        else
          "#{count} todo#{if count == 1, do: "", else: "s"} deleted"
        end

      socket =
        socket
        |> assign(show_bulk_modal: false, selected_ids: [])
        |> reload_todos()
        |> show_toast(message, "success")

      {:noreply, socket}
    rescue
      e -> {:noreply, show_toast(socket, "Bulk delete failed: #{Exception.message(e)}", "error")}
    end
  end

  # ─── EDIT MODAL ─────────────────────────────────────────────────────────────

  @impl true
  def handle_event("open_edit_modal", %{"id" => id}, socket) do
    todo = Todos.get_todo!(String.to_integer(id), socket.assigns.user.id)
    {:noreply, assign(socket, show_edit_modal: true, todo_to_edit: todo, edit_title: todo.title)}
  end

  @impl true
  # kept for backward compat but modal now uses phx-submit so this is rarely called
  def handle_event("update_edit_title", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, show_edit_modal: false, todo_to_edit: nil, edit_title: "")}
  end

  @impl true
  # phx-submit sends live DOM value at submit time — no stale-assign bugs
  def handle_event("confirm_edit", params, socket) do
    title = String.trim(params["edit_title"] || socket.assigns.edit_title || "")

    if title == "" do
      {:noreply, show_toast(socket, "Title cannot be empty", "error")}
    else
      try do
        case Todos.update_todo_title(socket.assigns.todo_to_edit, title) do
          {:ok, _} ->
            socket =
              socket
              |> assign(show_edit_modal: false, todo_to_edit: nil, edit_title: "")
              |> reload_todos()
              |> show_toast("Todo renamed to \"#{title}\"", "success")

            {:noreply, socket}

          {:error, changeset} ->
            {:noreply, show_toast(socket, format_changeset_error(changeset), "error")}
        end
      rescue
        e -> {:noreply, show_toast(socket, "Failed to update: #{Exception.message(e)}", "error")}
      end
    end
  end

  # ─── FAVORITES MODAL ────────────────────────────────────────────────────────

  @impl true
  def handle_event("open_favorites", _params, socket) do
    favs = Todos.get_favorite_todos(socket.assigns.user.id)
    {:noreply, assign(socket, show_favorites_modal: true, favorite_todos: favs)}
  end

  @impl true
  def handle_event("close_favorites", _params, socket) do
    {:noreply, assign(socket, show_favorites_modal: false)}
  end

  # ─── CREATE CATEGORY ────────────────────────────────────────────────────────

  @impl true
  def handle_event("open_new_category", _params, socket) do
    {:noreply, assign(socket, show_new_category_modal: true, new_category_name: "")}
  end

  @impl true
  def handle_event("cancel_category", _params, socket) do
    {:noreply,
     assign(socket, show_new_category_modal: false, new_category_name: "", form_category_id: "")}
  end

  @impl true
  # kept for backward compat; modal now uses phx-submit so this is rarely called
  def handle_event("update_new_category", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  # phx-submit sends live DOM value — works even if user types and clicks Confirm immediately
  def handle_event("confirm_new_category", params, socket) do
    # read from phx-submit params first; fall back to assign if fired via phx-click
    name = String.trim(params["new_category_name"] || socket.assigns.new_category_name || "")

    cond do
      name == "" ->
        {:noreply, show_toast(socket, "Category name cannot be empty", "error")}

      String.length(name) > 100 ->
        {:noreply, show_toast(socket, "Category name is too long (max 100 chars)", "error")}

      true ->
        try do
          case Todos.create_category(%{name: name, user_id: socket.assigns.user.id}) do
            {:ok, cat} ->
              categories = Todos.list_categories(socket.assigns.user.id)

              socket =
                socket
                |> assign(
                  categories: categories,
                  form_category_id: Integer.to_string(cat.id),
                  show_new_category_modal: false,
                  new_category_name: ""
                )
                |> show_toast("Category \"#{cat.name}\" created! 📂", "success")

              {:noreply, socket}

            {:error, changeset} ->
              msg =
                if Keyword.has_key?(changeset.errors, :name) do
                  "Category \"#{name}\" already exists"
                else
                  format_changeset_error(changeset)
                end

              {:noreply, show_toast(socket, msg, "error")}
          end
        rescue
          e ->
            {:noreply,
             show_toast(socket, "Failed to create category: #{Exception.message(e)}", "error")}
        end
    end
  end

  # ─── PAGINATION ─────────────────────────────────────────────────────────────

  @impl true
  def handle_event("page", %{"page" => page}, socket) do
    socket = assign(socket, current_page: String.to_integer(page), selected_ids: [])
    {:noreply, reload_todos(socket)}
  end

  # ─── TOAST CLOSE ────────────────────────────────────────────────────────────

  @impl true
  def handle_event("close_toast", _params, socket) do
    {:noreply, assign(socket, toast: nil)}
  end

  # ─── HELPERS ────────────────────────────────────────────────────────────────

  defp reload_todos(socket) do
    %{user: user, current_page: page, search: search, filter: filter} = socket.assigns
    result = Todos.list_todos(user.id, page: page, search: search, filter: filter)

    page =
      if result.total_pages > 0 and page > result.total_pages,
        do: result.total_pages,
        else: page

    assign(socket,
      todos: result.todos,
      total_pages: result.total_pages,
      current_page: page,
      total_items: result.total_items
    )
  end

  defp show_toast(socket, message, type) do
    Process.send_after(self(), :clear_toast, 3000)
    assign(socket, toast: message, toast_type: type)
  end

  @impl true
  @spec handle_info(:clear_toast, any()) :: {:noreply, any()}
  def handle_info(:clear_toast, socket) do
    {:noreply, assign(socket, toast: nil)}
  end

  # ─── RENDER ─────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="app-wrapper">
      <!-- Toast -->
      <%= if @toast do %>
        <div class={"toast toast-#{@toast_type}"}>
          <span>{@toast}</span>
          <button class="toast-close" phx-click="close_toast">✕</button>
        </div>
      <% end %>

      <div class="app-card">
        <!-- Header -->
        <div class="app-header">
          <button class="header-btn bookmark-btn" phx-click="open_favorites" title="Favorites">
            <i class="far fa-bookmark"></i>
          </button>
          <div class="brand">
            <span class="brand-icon">
              <img src="images/todo-app.png" alt="Logo" height="40" width="40" />
            </span>
            <h1 class="brand-name">Planora</h1>
          </div>
          <form method="post" action="/logout" style="margin:0">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <button type="submit" class="header-btn logout-btn">
              Logout <span>→</span>
            </button>
          </form>
        </div>

        <p class="app-subtitle">What do you want to do today?</p>
        
    <!-- Add Todo Form: phx-submit sends live DOM values; form_key recreates DOM on success -->
        <form id={"todo-form-#{@form_key}"} phx-submit="add_todo" class="todo-form">
          <div class="form-row">
            <label class="form-label-inline">Task Title</label>
            <input
              id="form-title"
              type="text"
              class="form-input"
              placeholder="Enter your task"
              name="title"
              autocomplete="off"
            />
          </div>

          <div class="form-row">
            <label class="form-label-inline">Category</label>
            <div style="flex:1; display:flex; flex-direction:column; gap:6px;">
              <select
                id="form-category"
                class="form-input form-select"
                name="category_id"
              >
                <option value="" disabled selected={@form_category_id == ""}>
                  {if @categories == [], do: "— no categories yet —", else: "Select a category"}
                </option>
                <%= for cat <- @categories do %>
                  <option value={cat.id} selected={Integer.to_string(cat.id) == @form_category_id}>
                    {cat.name}
                  </option>
                <% end %>
              </select>
              <!-- Dedicated button — always works, no native-select event quirks -->
              <button
                type="button"
                id="create-category-btn"
                class="create-cat-btn"
                phx-click="open_new_category"
              >
                ➕ Create New Category
              </button>
            </div>
          </div>

          <div class="form-row">
            <label class="form-label-inline">Description</label>
            <input
              id="form-description"
              type="text"
              class="form-input"
              placeholder="Enter task description"
              name="description"
              autocomplete="off"
            />
          </div>

          <div class="form-row">
            <label class="form-label-inline">Tags</label>
            <input
              id="form-tags"
              type="text"
              class="form-input"
              placeholder="Tags separated by comma (max 2)"
              name="tags"
              autocomplete="off"
            />
          </div>

          <button type="submit" class="add-btn">ADD</button>
        </form>
        
    <!-- Filter Bar -->
        <div class="filter-bar">
          <div class="select-all">
            <input
              type="checkbox"
              id="select-all-checkbox"
              class="checkbox"
              checked={length(@selected_ids) > 0 && length(@selected_ids) == length(@todos)}
              phx-click="select_all"
              disabled={@todos == []}
            />
            <label for="select-all-checkbox" class="filter-label">Select All</label>
          </div>

          <div class="filter-controls">
            <input
              id="search-input"
              type="text"
              class="search-input"
              placeholder="Search..."
              value={@search}
              phx-hook="SearchDebounce"
              name="search"
            />

            <%= for {label, val} <- [{"ALL", "ALL"}, {"COMPLETED", "completed"}, {"ON HOLD", "on-hold"}, {"IN PROGRESS", "in_progress"}] do %>
              <label class="radio-label">
                <input
                  type="radio"
                  name="filter"
                  value={val}
                  checked={@filter == val}
                  phx-click="filter"
                  phx-value-value={val}
                />
                {label}
              </label>
            <% end %>
          </div>
        </div>
        
    <!-- Todo List -->
        <div class="todo-list">
          <%= if @todos == [] do %>
            <div class="empty-state">
              <span class="empty-icon">📭</span>
              <p>No todos found. Add one above!</p>
            </div>
          <% else %>
            <%= for todo <- @todos do %>
              <div class="todo-item">
                <div class="todo-left">
                  <input
                    type="checkbox"
                    class="checkbox"
                    checked={todo.id in @selected_ids}
                    phx-click="toggle_select"
                    phx-value-id={todo.id}
                  />

                  <div class="todo-info">
                    <span class="todo-title">{todo.title}</span>
                    <span class="todo-desc">
                      {(fn d ->
                          if String.length(d) > 5, do: String.slice(d, 0, 5) <> "...", else: d
                        end).(String.trim(todo.description || ""))}
                    </span>
                    
    <!-- Tags -->
                    <div class="tag-list">
                      <%= for tag <- (todo.tags || []) do %>
                        <span class="tag-chip">
                          {tag.tagname}
                          <button
                            class="tag-remove"
                            phx-click="remove_tag"
                            phx-value-todo_id={todo.id}
                            phx-value-tag_id={tag.id}
                          >
                            ✕
                          </button>
                        </span>
                      <% end %>
                    </div>
                    
    <!-- Star Rating -->
                    <div class="star-rating">
                      <%= for i <- 1..5 do %>
                        <span class="star-group">
                          <button
                            class={"star-half #{if Decimal.compare(todo.rating || Decimal.new(0), Decimal.from_float(i - 0.5)) != :lt, do: "active", else: ""}"}
                            phx-click="rate_todo"
                            phx-value-id={todo.id}
                            phx-value-rating={"#{i - 0.5}"}
                            title={"#{i - 0.5} stars"}
                          >
                            ★
                          </button>
                          <button
                            class={"star-full #{if Decimal.compare(todo.rating || Decimal.new(0), Decimal.new(Integer.to_string(i))) != :lt, do: "active", else: ""}"}
                            phx-click="rate_todo"
                            phx-value-id={todo.id}
                            phx-value-rating={"#{i}.0"}
                            title={"#{i} stars"}
                          >
                            ★
                          </button>
                        </span>
                      <% end %>
                      <span class="rating-label">
                        {(fn r ->
                            if r == 0.0,
                              do: "Not rated",
                              else: "#{:erlang.float_to_binary(r, decimals: 1)}/5.0"
                          end).(todo.rating |> Decimal.to_float())}
                      </span>
                    </div>
                  </div>
                </div>

                <div class="todo-right">
                  <!-- Mini-form so phx-change sends both todo_id (hidden) and status (select) -->
                  <form phx-change="status_change" class="status-form">
                    <input type="hidden" name="todo_id" value={todo.id} />
                    <select
                      class={"status-select status-#{todo.status}"}
                      name="status"
                    >
                      <option value="in_progress" selected={todo.status == "in_progress"}>
                        In Progress
                      </option>
                      <option value="completed" selected={todo.status == "completed"}>
                        Completed
                      </option>
                      <option value="on-hold" selected={todo.status == "on-hold"}>On Hold</option>
                    </select>
                  </form>

                  <button
                    class="action-btn edit-btn"
                    phx-click="open_edit_modal"
                    phx-value-id={todo.id}
                    title="Edit"
                  >
                    <i class="fa-solid fa-pen-to-square"></i>
                  </button>

                  <button
                    class="action-btn delete-btn"
                    phx-click="open_delete_modal"
                    phx-value-id={todo.id}
                    title="Delete"
                  >
                    <i class="fa-solid fa-trash"></i>
                  </button>

                  <button
                    class="action-btn fav-btn"
                    phx-click="toggle_favorite"
                    phx-value-id={todo.id}
                    title={if todo.is_favorite, do: "Remove bookmark", else: "Bookmark"}
                  >
                    <i class={
                      if todo.is_favorite, do: "fa-solid fa-bookmark", else: "fa-regular fa-bookmark"
                    }>
                    </i>
                  </button>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
        
    <!-- Bottom Bar: bulk delete + pagination -->
        <div class="bottom-bar">
          <button
            class={"bulk-delete-btn #{if @selected_ids == [], do: "disabled"}"}
            phx-click="open_bulk_modal"
            disabled={@selected_ids == []}
          >
            Delete Selected
          </button>

          <div class="pagination">
            <button
              class="page-btn"
              phx-click="page"
              phx-value-page={@current_page - 1}
              disabled={@current_page <= 1}
            >
              ‹
            </button>

            <%= for p <- max(1, @current_page - 2)..min(@total_pages, @current_page + 2) do %>
              <button
                class={"page-btn #{if p == @current_page, do: "active"}"}
                phx-click="page"
                phx-value-page={p}
              >
                {p}
              </button>
            <% end %>

            <button
              class="page-btn"
              phx-click="page"
              phx-value-page={@current_page + 1}
              disabled={@current_page >= @total_pages}
            >
              ›
            </button>
          </div>
        </div>
      </div>
      
    <!-- Delete Confirm Modal -->
      <%= if @show_delete_modal do %>
        <div class="modal-overlay">
          <div class="modal-box" phx-click-away="cancel_delete">
            <div class="modal-header">
              <h3 class="modal-title">Confirm Delete</h3>
            </div>
            <div class="modal-body">
              <p>
                Are you sure you want to delete <strong>"<%= @todo_to_delete && @todo_to_delete.title %>"</strong>?
              </p>
            </div>
            <div class="modal-footer">
              <button class="modal-btn cancel" phx-click="cancel_delete">Cancel</button>
              <button class="modal-btn confirm" phx-click="confirm_delete">Delete</button>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Bulk Delete Modal -->
      <%= if @show_bulk_modal do %>
        <div class="modal-overlay">
          <div class="modal-box" phx-click-away="cancel_bulk">
            <div class="modal-header">
              <h3 class="modal-title">Delete Selected Todos</h3>
            </div>
            <div class="modal-body">
              <p>
                Are you sure you want to delete <strong>{length(@selected_ids)}</strong>
                selected {if length(@selected_ids) == 1, do: "todo", else: "todos"}?
              </p>
            </div>
            <div class="modal-footer">
              <button class="modal-btn cancel" phx-click="cancel_bulk">Cancel</button>
              <button class="modal-btn confirm" phx-click="confirm_bulk_delete">Delete All</button>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Edit Modal: phx-submit form captures live DOM value at submit time -->
      <%= if @show_edit_modal do %>
        <div class="modal-overlay">
          <div class="modal-box" phx-click-away="cancel_edit">
            <div class="modal-header">
              <h3 class="modal-title">Edit Todo Title</h3>
            </div>
            <form id="edit-title-form" phx-submit="confirm_edit" class="modal-body">
              <input
                type="text"
                id="edit-title-input"
                class="form-input"
                value={@edit_title}
                name="edit_title"
                placeholder="Enter new title"
                autocomplete="off"
              />
            </form>
            <div class="modal-footer">
              <button class="modal-btn cancel" phx-click="cancel_edit">Cancel</button>
              <button class="modal-btn confirm" type="submit" form="edit-title-form">Save</button>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Favorites Modal -->
      <%= if @show_favorites_modal do %>
        <div class="modal-overlay">
          <div class="modal-box" phx-click-away="close_favorites">
            <div class="modal-header">
              <h3 class="modal-title"><i class="fa fa-star"></i>Favorite Todos</h3>
            </div>
            <div class="modal-body">
              <%= if @favorite_todos == [] do %>
                <p class="empty-favs">No favorites yet ❤️</p>
              <% else %>
                <div class="fav-list">
                  <%= for {todo, idx} <- Enum.with_index(@favorite_todos, 1) do %>
                    <div class="fav-item">{idx}. {todo.title}</div>
                  <% end %>
                </div>
              <% end %>
            </div>
            <div class="modal-footer">
              <button class="modal-btn confirm" phx-click="close_favorites">Close</button>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- New Category Modal: phx-submit form captures live input value -->
      <%= if @show_new_category_modal do %>
        <div class="modal-overlay">
          <div class="modal-box" phx-click-away="cancel_category">
            <div class="modal-header">
              <h3 class="modal-title">Create New Category</h3>
            </div>
            <form id="new-cat-form" phx-submit="confirm_new_category" class="modal-body">
              <input
                type="text"
                id="new-category-input"
                class="form-input"
                placeholder="e.g. Work, Personal, Shopping"
                name="new_category_name"
                autocomplete="off"
              />
            </form>
            <div class="modal-footer">
              <button class="modal-btn cancel" phx-click="cancel_category">Cancel</button>
              <button class="modal-btn confirm" type="submit" form="new-cat-form">Create</button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ─── HELPERS ────────────────────────────────────────────────────────────────

  defp format_changeset_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      field_name = field |> to_string() |> String.replace("_", " ") |> String.capitalize()
      "#{field_name}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join(" | ")
  end
end
