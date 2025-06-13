defmodule TaskOverlordDemoWeb.TaskCard do
  @moduledoc false

  use TaskOverlordDemoWeb, :live_component

  attr :module, :string, required: true
  attr :status, :string, required: true
  attr :status_color, :string, default: "text-green-600"
  attr :msg, :string, required: true
  attr :started, :string, required: true
  attr :completed, :string, required: true
  attr :duration, :string, required: true
  attr :result, :string, required: true
  attr :age, :string, required: true
  attr :exp, :string, required: true
  attr :on_discard, :any, default: nil

  def task_card(assigns) do
    ~H"""
    <div class="border rounded-lg shadow-sm p-4 flex flex-col gap-2 bg-white relative max-w-md">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <span class="font-mono text-sm text-gray-700">{@module}</span>
        <div class="flex gap-2">
          <span class="bg-blue-50 text-blue-700 text-xs font-semibold px-2 py-0.5 rounded">
            Age: {@age}
          </span>
          <span class="bg-gray-100 text-gray-500 text-xs font-semibold px-2 py-0.5 rounded">
            Exp: {@exp}
          </span>
        </div>
      </div>
      
    <!-- Status -->
      <div>
        <span class={"font-semibold #{@status_color}"}>Status: {@status}</span>
      </div>
      
    <!-- Message -->
      <div class="text-gray-700 text-sm">
        Msg: {@msg}
      </div>
      
    <!-- Times and duration -->
      <div class="text-xs text-gray-500">
        Started: {@started}<br /> Completed: {@completed}<br /> Duration: {@duration}
      </div>
      
    <!-- Result -->
      <div class="text-xs text-gray-700">
        Result: {@result}
      </div>
      
    <!-- Discard Button -->
      <button
        type="button"
        class="absolute bottom-3 left-4 flex items-center gap-1 px-3 py-1 rounded bg-gradient-to-r from-orange-400 to-red-500 text-white font-semibold shadow hover:from-orange-500 hover:to-red-600 transition-all text-sm"
        phx-click={@on_discard}
      >
        <span class="text-lg">✕</span> Discard
      </button>
    </div>
    """
  end
end
