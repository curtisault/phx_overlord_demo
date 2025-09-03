defmodule TaskOverlordDemo.Overlord.Task do
  @moduledoc false

  use GenServer

  require Logger

  import TaskOverlordDemo.Overlord

  @pub_sub_topic pub_sub_topic(__MODULE__)
  @default_timeout default_timeout()
  @discard_interval discard_interval()

  defstruct [
    :task,
    :result
  ]

  @type t() :: %__MODULE__{
          task: TaskOverlordDemo.Overlord.t(),
          result: any() | nil
        }

  def make_task(%Task{} = beam_task, %{heading: _heading, message: _message} = attrs, opts \\ []) do
    prm = {beam_task.pid, beam_task.ref, beam_task.mfa}

    default_opts = [
      status: :running,
      logs: Keyword.get(opts, :logs, []),
      started_at: Keyword.get(opts, :started_at, DateTime.utc_now()),
      expires_at_unix: Keyword.get(opts, :expires_at_unix, nil)
    ]

    task = make(prm, attrs, Keyword.merge(opts, default_opts))

    %__MODULE__{
      task: task,
      result: nil
    }
  end

  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(TaskOverlordDemo.PubSub, @pub_sub_topic)

  def subscribe(pid) do
    Phoenix.PubSub.subscribe(TaskOverlordDemo.PubSub, @pub_sub_topic, pid: pid)
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @type func() :: (-> any())

  @doc """
  Run a task with a function or a tuple of module, function, and arguments.
  The task will be run asynchronously, and the result will be tracked.

  If the current process terminates, the task will also be terminated.
  """
  @spec async({module(), func()} | {module(), atom(), list()}) :: :ok
  def async(tuple, attrs \\ %{})

  def async(func, attrs) when is_function(func, 0) do
    GenServer.cast(__MODULE__, {:async_task, func, attrs})
  end

  def async({module, func, args, opts}, attrs) when is_function(func) and is_list(args) do
    GenServer.cast(__MODULE__, {:async_task, {module, func, args, opts}, attrs})
  end

  def async(_func, _attrs) do
    raise ArgumentError, "Invalid args provided."
  end

  @doc """
  Run a task with a function or a tuple of module, function, and arguments.
  The task will be run asynchronously, and the result will be tracked.

  If the current process terminates, the task will continue to run independently.
  """
  @spec async_task_nolink({module(), func()} | {module(), atom(), list()}, map()) :: :ok
  def async_task_nolink(fun_or_tuple, attrs \\ %{})

  def async_task_nolink(func, attrs) when is_function(func, 0) do
    GenServer.cast(__MODULE__, {:async_task_nolink, func, attrs})
  end

  def async_task_nolink({module, func, args}, attrs) when is_function(func) and is_list(args) do
    GenServer.cast(__MODULE__, {:async_task_nolink, {module, func, args}, attrs})
  end

  def async_task_nolink(_fun, _attrs) do
    raise ArgumentError, "Invalid args provided."
  end

  @doc """
  Run a task with a function or a tuple of module, function, and arguments.
  The task will be run asynchronously, and the result will be tracked.

  If the current process terminates, the task will also be terminated.
  """
  @spec run_task({module(), func()} | {module(), atom(), list()}) :: :ok
  def run_task(tuple, attrs \\ %{})

  def run_task(func, attrs) when is_function(func, 0) do
    GenServer.call(__MODULE__, {:run_task, func, attrs})
  end

  def run_task({module, func, args, opts}, attrs) when is_function(func) and is_list(args) do
    GenServer.call(__MODULE__, {:run_task, {module, func, args, opts}, attrs})
  end

  def run_task(_func, _attrs) do
    raise ArgumentError, "Invalid args provided."
  end

  def run_task_nolink(tuple, attrs \\ %{})

  def run_task_nolink(func, attrs) when is_function(func, 0) do
    GenServer.call(__MODULE__, {:run_task_nolink, func, attrs})
  end

  def run_task_nolink({module, func, args}, attrs) when is_function(func) and is_list(args) do
    GenServer.call(__MODULE__, {:run_task_nolink, {module, func, args}, attrs})
  end

  @spec discard_task(String.t()) :: :ok
  def discard_task(ref), do: GenServer.call(__MODULE__, {:discard_task, ref})

  @spec list_tasks() :: map()
  def list_tasks, do: GenServer.call(__MODULE__, :list_tasks)

  # Callbacks

  def init(_) do
    Process.send_after(self(), :discard_outdated, @discard_interval)
    {:ok, %{tasks: %{}}}
  end

  # ~~~~~~~~~~~~~~ CAST handlers ~~~~~~~~~~~~~~

  # No arguments
  def handle_cast({:async_task, func, attrs}, %{tasks: tasks} = state) do
    task = Task.Supervisor.async(TaskOverlord.TaskSupervisor, func, default_task_opts())
    task_state = make_task(task, attrs)
    new_tasks = Map.put(tasks, task_state.task.ref, task_state)
    new_state = %{state | tasks: new_tasks}
    {:noreply, broadcast(new_state)}
  end

  # With arguments
  def handle_cast({:async_task, {module, func, args}, attrs}, %{tasks: tasks} = state) do
    task =
      Task.Supervisor.async(TaskOverlord.TaskSupervisor, module, func, args, default_task_opts())

    task_state = make_task(task, attrs)
    new_tasks = Map.put(tasks, task_state.task.ref, task_state)
    new_state = %{state | tasks: new_tasks}
    {:noreply, broadcast(new_state)}
  end

  # ~~~~~~~~~~~~~~ CALL handlers ~~~~~~~~~~~~~~

  # No arguments
  def handle_call({:run_task, fun, attrs}, _from, %{tasks: tasks} = state)
      when is_function(fun, 0) do
    task = Task.Supervisor.async(TaskOverlord.TaskSupervisor, fun, default_task_opts())

    task_state = make_task(task, attrs)
    new_tasks = Map.put(tasks, task_state.task.ref, task_state)
    new_state = %{state | tasks: new_tasks}

    {:reply, task, broadcast(new_state)}
  end

  # With arguments
  def handle_call(
        {:run_task, {module, func, args, opts}, attrs},
        _from,
        %{tasks: tasks} = state
      ) do
    task =
      Task.Supervisor.async(
        TaskOverlord.TaskSupervisor,
        module,
        func,
        args,
        default_task_opts(opts)
      )

    task_state = make_task(task, attrs)
    new_tasks = Map.put(tasks, task_state.task.ref, task_state)
    new_state = %{state | tasks: new_tasks}

    {:reply, task, broadcast(new_state)}
  end

  # No arguments
  def handle_call({:run_task_nolink, func, attrs}, _from, %{tasks: tasks} = state) do
    task = Task.Supervisor.async_nolink(TaskOverlord.TaskSupervisor, func, default_task_opts())

    task_state = make_task(task, attrs)
    new_tasks = Map.put(tasks, task_state.task.ref, task_state)
    new_state = %{state | tasks: new_tasks}

    {:reply, task, broadcast(new_state)}
  end

  # With arguments
  def handle_call(
        {:run_task_nolink, {module, func, args}, attrs},
        _from,
        %{tasks: tasks} = state
      ) do
    task =
      Task.Supervisor.async_nolink(
        TaskOverlord.TaskSupervisor,
        module,
        func,
        args,
        default_task_opts()
      )

    task_state = make_task(task, attrs)
    new_tasks = Map.put(tasks, task_state.task.ref, task_state)
    new_state = %{state | tasks: new_tasks}

    {:reply, task, broadcast(new_state)}
  end

  def handle_call({:get_task, ref}, _from, %{tasks: tasks} = state) when is_reference(ref) do
    case Map.get(tasks, ref) do
      nil -> {:reply, {:error, :not_found}, state}
      task -> {:reply, {:ok, task}, state}
    end
  end

  def handle_call(:list_tasks, _from, state) do
    {:reply, state.tasks, state}
  end

  def handle_call({:discard_task, encoded_ref}, _from, state) do
    updated_tasks = Map.delete(state.tasks, decode_ref(encoded_ref))
    updated_state = %{state | tasks: updated_tasks}
    {:reply, :ok, broadcast(updated_state)}
  end

  # Handle task failure
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    updated_tasks =
      Map.update!(state.tasks, ref, fn task -> %{task | status: :error, result: reason} end)

    updated_state = %{state | tasks: updated_tasks}
    {:noreply, broadcast(updated_state)}
  end

  def handle_info(:discard_outdated, %{tasks: tasks} = state) do
    updated_tasks =
      tasks
      |> Enum.reject(fn {_id, %{task: task}} -> expired?(task) end)
      |> Map.new()

    updated_state = %{state | tasks: updated_tasks}
    Process.send_after(self(), :discard_outdated, @discard_interval)

    {:noreply, broadcast(updated_state)}
  end

  # Handle task completion
  def handle_info({ref, result}, state) do
    Process.demonitor(ref, [:flush])

    updated_tasks =
      Map.update!(state.tasks, ref, fn task ->
        %{task | status: :done, finished_at: DateTime.utc_now(), result: result}
      end)

    updated_state = %{state | tasks: updated_tasks}
    {:noreply, broadcast(updated_state)}
  end

  defp default_task_opts() do
    Keyword.new(timeout: @default_timeout, on_timeout: :kill_task)
  end

  defp default_task_opts(opts) do
    Keyword.merge(
      [
        timeout: @default_timeout,
        on_timeout: :kill_task
      ],
      opts
    )
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(
      TaskOverlordDemo.PubSub,
      @pub_sub_topic,
      {:task_overlord_updated, state}
    )

    state
  end
end
