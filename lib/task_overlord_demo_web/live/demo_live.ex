defmodule TaskOverlordDemoWeb.DemoLive do
  use TaskOverlordDemoWeb, :live_view

  alias TaskOverlordDemo.Overlord.Task
  alias TaskOverlordDemo.Overlord.Stream

  def mount(_params, _session, socket) do
    {:ok, socket}
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

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-6">
      <div class="max-w-4xl mx-auto">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900 mb-4">Task Overlord Demo</h1>
          <p class="text-gray-600 mb-6">Create tasks and streams to see them in the dashboard</p>

          <.link
            navigate="/dashboard"
            class="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors font-medium"
          >
            View Dashboard →
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
