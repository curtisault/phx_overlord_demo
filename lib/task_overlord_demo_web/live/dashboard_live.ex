defmodule TaskOverlordDemoWeb.DashboardLive do
  use TaskOverlordDemoWeb, :live_view

  alias TaskOverlordDemo.Overlord.Task
  alias TaskOverlordDemo.Overlord.Stream

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Task.subscribe()
      Stream.subscribe()
    end

    tasks = Task.list_tasks()

    socket =
      socket
      |> assign(:all_items, Map.values(tasks))
      |> categorize_items()

    {:ok, socket}
  end

  def handle_info({:task_overlord_updated, %{tasks: items}}, socket) do
    socket =
      socket
      |> assign(:all_items, Map.values(items))
      |> categorize_items()

    {:noreply, socket}
  end

  def handle_event("discard_task", %{"ref" => ref}, socket) do
    Task.discard_task(ref)
    {:noreply, socket}
  end

  def handle_event("create_quick_task", _, socket) do
    Task.async(
      fn ->
        Process.sleep(2000)
        "Quick task completed at #{DateTime.utc_now()}"
      end,
      %{heading: "Quick Task", message: "A simple 2-second task"}
    )

    {:noreply, socket}
  end

  def handle_event("create_long_task", _, socket) do
    Task.async(
      fn ->
        Process.sleep(10000)
        "Long task completed at #{DateTime.utc_now()}"
      end,
      %{heading: "Long Task", message: "A 10-second background task"}
    )

    {:noreply, socket}
  end

  def handle_event("create_error_task", _, socket) do
    Task.async(
      fn ->
        Process.sleep(1000)
        raise "Intentional error for testing"
      end,
      %{heading: "Error Task", message: "This task will fail on purpose"}
    )

    {:noreply, socket}
  end

  def handle_event("create_stream", _, socket) do
    Stream.async_stream(
      1..5,
      {Process, :sleep, [1000]},
      %{heading: "Number Stream", message: "Processing numbers 1-5 with 1s delay each"}
    )

    {:noreply, socket}
  end

  def handle_event("create_string_stream", _, socket) do
    words = ["hello", "world", "elixir", "phoenix", "liveview"]

    Stream.async_stream(
      words,
      {String, :upcase, []},
      %{heading: "String Stream", message: "Converting words to uppercase"}
    )

    {:noreply, socket}
  end

  defp categorize_items(socket) do
    all_items = socket.assigns.all_items

    running = Enum.filter(all_items, &item_status_matches?(&1, [:running, :streaming]))
    completed = Enum.filter(all_items, &item_status_matches?(&1, [:done, :completed]))
    error = Enum.filter(all_items, &item_status_matches?(&1, [:error, :failed]))

    socket
    |> assign(:running_items, running)
    |> assign(:completed_items, completed)
    |> assign(:error_items, error)
  end

  defp item_status_matches?(%{task: %{status: status}}, statuses), do: status in statuses
  defp item_status_matches?(%{stream: %{status: status}}, statuses), do: status in statuses
  defp item_status_matches?(_, _), do: false

  defp get_item_type(%{task: _}), do: "Task"
  defp get_item_type(%{stream: _}), do: "Stream"

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
    |> String.replace("Z", "")
  end

  defp calculate_duration(nil, _), do: "N/A"
  defp calculate_duration(_, nil), do: "Running..."

  defp calculate_duration(started, finished) do
    diff = DateTime.diff(finished, started, :second)
    "#{diff}s"
  end

  defp format_result(nil), do: "N/A"

  defp format_result(result) when is_binary(result) and byte_size(result) > 100 do
    String.slice(result, 0, 100) <> "..."
  end

  defp format_result(result), do: inspect(result)

  defp calculate_age(started_at) do
    diff = DateTime.diff(DateTime.utc_now(), started_at, :second)
    "#{diff}s"
  end

  defp status_color(:running), do: "text-blue-600"
  defp status_color(:streaming), do: "text-blue-600"
  defp status_color(:done), do: "text-green-600"
  defp status_color(:completed), do: "text-green-600"
  defp status_color(:error), do: "text-red-600"
  defp status_color(:failed), do: "text-red-600"
  defp status_color(_), do: "text-gray-600"

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-6">
      <div class="w-full px-2">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">Task Overlord Dashboard</h1>
        
    <!-- Task and Stream Creation Buttons -->
        <div class="mb-8 grid grid-cols-1 md:grid-cols-2 gap-8">
          <!-- Tasks Section -->
          <div class="bg-gradient-to-br from-white to-gray-50 rounded-xl shadow-lg border border-gray-100 p-6">
            <div class="flex items-center gap-3 mb-6">
              <div class="w-10 h-10 bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
                <div class="w-5 h-5 bg-white rounded-sm flex items-center justify-center">
                  <div class="w-3 h-3 bg-gradient-to-r from-blue-500 to-purple-600 rounded-xs"></div>
                </div>
              </div>
              <h2 class="text-xl font-bold bg-gradient-to-r from-gray-800 to-gray-600 bg-clip-text text-transparent">
                Create Tasks
              </h2>
            </div>
            <div class="space-y-4">
              <button
                phx-click="create_quick_task"
                class="group relative w-full bg-gradient-to-r from-emerald-500 to-green-600 text-white py-4 px-6 rounded-xl font-semibold shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 transition-all duration-200 overflow-hidden"
              >
                <div class="absolute inset-0 bg-gradient-to-r from-emerald-400 to-green-500 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                </div>
                <div class="relative flex items-center justify-center gap-3">
                  <div class="w-5 h-5 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                    <div class="w-2 h-2 bg-white rounded-full animate-pulse"></div>
                  </div>
                  <span>⚡ Quick Task (2s)</span>
                </div>
              </button>

              <button
                phx-click="create_long_task"
                class="group relative w-full bg-gradient-to-r from-blue-500 to-cyan-600 text-white py-4 px-6 rounded-xl font-semibold shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 transition-all duration-200 overflow-hidden"
              >
                <div class="absolute inset-0 bg-gradient-to-r from-blue-400 to-cyan-500 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                </div>
                <div class="relative flex items-center justify-center gap-3">
                  <div class="w-5 h-5 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                    <div class="w-2 h-2 bg-white rounded-full"></div>
                  </div>
                  <span>🕐 Long Task (10s)</span>
                </div>
              </button>

              <button
                phx-click="create_error_task"
                class="group relative w-full bg-gradient-to-r from-red-500 to-rose-600 text-white py-4 px-6 rounded-xl font-semibold shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 transition-all duration-200 overflow-hidden"
              >
                <div class="absolute inset-0 bg-gradient-to-r from-red-400 to-rose-500 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                </div>
                <div class="relative flex items-center justify-center gap-3">
                  <div class="w-5 h-5 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                    <div class="w-2 h-2 bg-white rounded-full"></div>
                  </div>
                  <span>💥 Error Task (will fail)</span>
                </div>
              </button>
            </div>
          </div>
          
    <!-- Streams Section -->
          <div class="bg-gradient-to-br from-white to-gray-50 rounded-xl shadow-lg border border-gray-100 p-6">
            <div class="flex items-center gap-3 mb-6">
              <div class="w-10 h-10 bg-gradient-to-r from-purple-500 to-pink-600 rounded-lg flex items-center justify-center">
                <div class="w-5 h-5 bg-white rounded-sm flex items-center justify-center">
                  <div class="w-3 h-3 bg-gradient-to-r from-purple-500 to-pink-600 rounded-xs"></div>
                </div>
              </div>
              <h2 class="text-xl font-bold bg-gradient-to-r from-gray-800 to-gray-600 bg-clip-text text-transparent">
                Create Streams
              </h2>
            </div>
            <div class="space-y-4">
              <button
                phx-click="create_stream"
                class="group relative w-full bg-gradient-to-r from-purple-500 to-violet-600 text-white py-4 px-6 rounded-xl font-semibold shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 transition-all duration-200 overflow-hidden"
              >
                <div class="absolute inset-0 bg-gradient-to-r from-purple-400 to-violet-500 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                </div>
                <div class="relative flex items-center justify-center gap-3">
                  <div class="w-5 h-5 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                    <div class="flex gap-1">
                      <div
                        class="w-1 h-1 bg-white rounded-full animate-bounce"
                        style="animation-delay: 0s"
                      >
                      </div>
                      <div
                        class="w-1 h-1 bg-white rounded-full animate-bounce"
                        style="animation-delay: 0.1s"
                      >
                      </div>
                      <div
                        class="w-1 h-1 bg-white rounded-full animate-bounce"
                        style="animation-delay: 0.2s"
                      >
                      </div>
                    </div>
                  </div>
                  <span>🔢 Number Stream (1-5)</span>
                </div>
              </button>

              <button
                phx-click="create_string_stream"
                class="group relative w-full bg-gradient-to-r from-indigo-500 to-purple-600 text-white py-4 px-6 rounded-xl font-semibold shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 transition-all duration-200 overflow-hidden"
              >
                <div class="absolute inset-0 bg-gradient-to-r from-indigo-400 to-purple-500 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                </div>
                <div class="relative flex items-center justify-center gap-3">
                  <div class="w-5 h-5 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                    <div class="flex gap-1">
                      <div
                        class="w-1 h-1 bg-white rounded-full animate-pulse"
                        style="animation-delay: 0s"
                      >
                      </div>
                      <div
                        class="w-1 h-1 bg-white rounded-full animate-pulse"
                        style="animation-delay: 0.2s"
                      >
                      </div>
                      <div
                        class="w-1 h-1 bg-white rounded-full animate-pulse"
                        style="animation-delay: 0.4s"
                      >
                      </div>
                    </div>
                  </div>
                  <span>📝 String Stream (words)</span>
                </div>
              </button>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Running Column -->
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-blue-600 mb-4 flex items-center gap-2">
              <div class="w-3 h-3 bg-blue-500 rounded-full animate-pulse"></div>
              Running ({length(@running_items)})
            </h2>
            <div class="space-y-4 max-h-96 overflow-y-auto">
              <%= for item <- @running_items do %>
                <.render_item_card item={item} />
              <% end %>
              <%= if Enum.empty?(@running_items) do %>
                <p class="text-gray-500 text-sm">No running tasks</p>
              <% end %>
            </div>
          </div>
          
    <!-- Completed Column -->
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-green-600 mb-4 flex items-center gap-2">
              <div class="w-3 h-3 bg-green-500 rounded-full"></div>
              Completed ({length(@completed_items)})
            </h2>
            <div class="space-y-4 max-h-96 overflow-y-auto">
              <%= for item <- @completed_items do %>
                <.render_item_card item={item} />
              <% end %>
              <%= if Enum.empty?(@completed_items) do %>
                <p class="text-gray-500 text-sm">No completed tasks</p>
              <% end %>
            </div>
          </div>
          
    <!-- Error Column -->
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-red-600 mb-4 flex items-center gap-2">
              <div class="w-3 h-3 bg-red-500 rounded-full"></div>
              Error ({length(@error_items)})
            </h2>
            <div class="space-y-4 max-h-96 overflow-y-auto">
              <%= for item <- @error_items do %>
                <.render_item_card item={item} />
              <% end %>
              <%= if Enum.empty?(@error_items) do %>
                <p class="text-gray-500 text-sm">No failed tasks</p>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_item_card(assigns) do
    ~H"""
    <div class="border rounded-lg p-4 bg-gray-50 hover:bg-gray-100 transition-colors">
      <div class="flex items-start justify-between mb-2">
        <span class="font-medium text-sm text-gray-700">{get_item_type(@item)}</span>
        <span class={"text-xs font-semibold px-2 py-1 rounded #{status_color(get_status(@item))}"}>
          {get_status(@item) |> to_string() |> String.upcase()}
        </span>
      </div>

      <div class="text-sm text-gray-900 mb-2">
        {get_heading(@item)}
      </div>

      <div class="text-xs text-gray-600 mb-2">
        {get_message(@item)}
      </div>

      <div class="text-xs text-gray-500 space-y-1">
        <div>Started: {format_datetime(get_started_at(@item))}</div>
        <%= if get_finished_at(@item) do %>
          <div>Finished: {format_datetime(get_finished_at(@item))}</div>
          <div>Duration: {calculate_duration(get_started_at(@item), get_finished_at(@item))}</div>
        <% else %>
          <div>Duration: {calculate_age(get_started_at(@item))}</div>
        <% end %>

        <%= if get_item_type(@item) == "Stream" do %>
          <div class="text-blue-600">
            Progress: {get_stream_completed(@item)}/{get_stream_total(@item)}
          </div>
        <% end %>

        <%= if get_result(@item) && get_result(@item) != nil do %>
          <div class="mt-2 p-2 bg-white rounded border">
            <div class="text-xs font-medium text-gray-700">Result:</div>
            <div class="text-xs text-gray-600 font-mono mt-1 break-all">
              {format_result(get_result(@item))}
            </div>
          </div>
        <% end %>
      </div>

      <%= if get_status(@item) in [:done, :completed, :error, :failed] do %>
        <button
          phx-click="discard_task"
          phx-value-ref={encode_ref(get_ref(@item))}
          class="group relative mt-3 bg-gradient-to-r from-red-500 to-rose-600 text-white text-xs font-semibold px-3 py-2 rounded-lg shadow-md hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 overflow-hidden"
        >
          <div class="absolute inset-0 bg-gradient-to-r from-red-400 to-rose-500 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
          </div>
          <div class="relative flex items-center justify-center gap-1">
            <span>🗑️</span>
            <span>Discard</span>
          </div>
        </button>
      <% end %>
    </div>
    """
  end

  defp get_status(%{task: %{status: status}}), do: status
  defp get_status(%{stream: %{status: status}}), do: status

  defp get_heading(%{task: %{heading: heading}}), do: heading
  defp get_heading(%{stream: %{heading: heading}}), do: heading

  defp get_message(%{task: %{message: message}}), do: message
  defp get_message(%{stream: %{message: message}}), do: message

  defp get_started_at(%{started_at: started}), do: started
  defp get_started_at(%{task: %{started_at: started}}), do: started
  defp get_started_at(%{stream: %{started_at: started}}), do: started

  defp get_finished_at(%{finished_at: finished}), do: finished
  defp get_finished_at(%{task: %{finished_at: finished}}), do: finished
  defp get_finished_at(%{stream: %{finished_at: finished}}), do: finished

  defp get_result(%{result: result}), do: result
  defp get_result(%{results: results}) when is_list(results), do: results
  defp get_result(_), do: nil

  defp get_ref(%{task: %{ref: ref}}), do: ref
  defp get_ref(%{stream: %{ref: ref}}), do: ref

  defp get_stream_completed(%{stream_completed: completed}), do: completed
  defp get_stream_completed(_), do: 0

  defp get_stream_total(%{stream_total: total}), do: total
  defp get_stream_total(_), do: 0

  defp encode_ref(ref) when is_reference(ref) do
    ref
    |> :erlang.term_to_binary()
    |> Base.encode64(padding: false)
  end
end
