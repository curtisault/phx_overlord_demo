defmodule TaskOverlordDemo.Overlord.Stream do
  @moduledoc false

  use GenServer

  require Logger

  import TaskOverlordDemo.Overlord

  @pub_sub_topic pub_sub_topic(__MODULE__)
  @default_timeout default_timeout()
  @discard_interval discard_interval()

  defstruct [
    :stream,
    :enum,
    :stream_completed,
    :stream_total,
    :results
  ]

  @type t() :: %__MODULE__{
          stream: TaskOverlordDemo.Overlord.t(),
          enum: Enumerable.t(),
          stream_completed: non_neg_integer(),
          stream_total: non_neg_integer(),
          results: list()
        }

  defguard list_of_functions?(list)
           when is_list(list) and
                  not list == [] and
                  is_function(hd(list))

  defguard is_enum_and_mfa?(enum, mfa)
           when is_list(enum) and
                  is_tuple(mfa) and
                  tuple_size(mfa) == 3

  # NOTE: Never explicitly check for Stream struct (https://hexdocs.pm/elixir/Stream.html#module-creating-streams)
  def make_stream(enum, funcs_or_mfa, attrs, opts \\ [])

  def make_stream(enum, funcs, %{heading: _heading, message: _message} = attrs, opts)
      when list_of_functions?(funcs) do
    # No PID for stream
    prm = {nil, make_ref(), {__MODULE__, :async_stream, []}}

    default_opts = [
      status: Keyword.get(opts, :status, :streaming),
      logs: Keyword.get(opts, :logs, []),
      started_at: Keyword.get(opts, :started_at, DateTime.utc_now()),
      expires_at_unix: Keyword.get(opts, :expires_at_unix, nil)
    ]

    %__MODULE__{
      stream: make(prm, attrs, Keyword.merge(opts, default_opts)),
      enum: enum,
      stream_completed: 0,
      stream_total: Enum.count(enum) || 0,
      results: []
    }
  end

  def make_stream(enum, mfa, %{heading: _heading, message: _message} = attrs, opts)
      when is_enum_and_mfa?(enum, mfa) do
    # No PID for stream
    prm = {nil, make_ref(), mfa}

    default_opts = [
      status: Keyword.get(opts, :status, :streaming),
      logs: Keyword.get(opts, :logs, []),
      started_at: Keyword.get(opts, :started_at, DateTime.utc_now()),
      expires_at_unix: Keyword.get(opts, :expires_at_unix, nil)
    ]

    %__MODULE__{
      stream: make(prm, attrs, Keyword.merge(opts, default_opts)),
      enum: enum,
      stream_completed: 0,
      stream_total: Enum.count(enum) || 0,
      results: []
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

  @doc """
  Run a stream of functions or a stream of tuples of module, function, and arguments.
  The task will be run asynchronously, and the results will be tracked.

  If the current process terminates, the task will also be terminated.
  """
  @spec async_stream(Enumerable.t(), {module(), atom(), list(), Keyword.t()}, map()) :: :ok
  def async_stream(funcs, attrs) when is_list(funcs) and is_map(attrs) do
    GenServer.cast(__MODULE__, {:async_stream, funcs, attrs})
  end

  @spec async_stream(Enumerable.t(), {module(), atom()}, map()) :: :ok
  def async_stream(enumerable, {module, func}, attrs) when is_atom(func) do
    GenServer.cast(
      __MODULE__,
      {:async_stream, enumerable, {module, func, [], []}, attrs}
    )
  end

  @spec async_stream(Enumerable.t(), {module(), atom(), list()}, map()) :: :ok
  def async_stream(enumerable, {module, func, args}, attrs)
      when is_atom(func) and is_list(args) do
    GenServer.cast(
      __MODULE__,
      {:async_stream, enumerable, {module, func, args, []}, attrs}
    )
  end

  @spec async_stream(Enumerable.t(), {module(), atom(), list(), Keyword.t()}, map()) :: :ok
  def async_stream(enumerable, {module, func, args, opts}, attrs)
      when is_atom(func) and is_list(args) and is_list(opts) do
    GenServer.cast(
      __MODULE__,
      {:async_stream, enumerable, {module, func, args, opts}, attrs}
    )
  end

  def async(enum, args, attrs) do
    raise ArgumentError,
          """
          Invalid args. 
            enum: #{inspect(enum)}
            args: #{inspect(args)}
            attrs: #{inspect(attrs)}
          """
  end

  @doc """
  Run a stream of functions or a stream of tuples of module, function, and arguments.
  The task will be run asynchronously, and the results will be tracked.

  If the current process terminates, the task will continue to run independently.
  """
  @spec async_stream_nolink(Enumerable.t(), {module(), atom(), list(), Keyword.t()}, map()) :: :ok
  def async_stream_nolink(funcs, attrs) when is_list(funcs) and is_map(attrs) do
    GenServer.cast(__MODULE__, {:async_stream_nolink, funcs, attrs})
  end

  @spec async_stream_nolink(Enumerable.t(), {module(), atom()}, map()) :: :ok
  def async_stream_nolink(enumerable, {module, func}, attrs) when is_atom(func) do
    GenServer.cast(
      __MODULE__,
      {:async_stream_nolink, enumerable, {module, func, [], []}, attrs}
    )
  end

  @spec async_stream_nolink(Enumerable.t(), {module(), atom(), list()}, map()) :: :ok
  def async_stream_nolink(enumerable, {module, func, args}, attrs)
      when is_atom(func) and is_list(args) do
    GenServer.cast(
      __MODULE__,
      {:async_stream_nolink, enumerable, {module, func, args, []}, attrs}
    )
  end

  @spec async_stream_nolink(Enumerable.t(), {module(), atom(), list(), Keyword.t()}, map()) :: :ok
  def async_stream_nolink(enumerable, {module, func, args, opts}, attrs)
      when is_atom(func) and is_list(args) and is_list(opts) do
    GenServer.cast(
      __MODULE__,
      {:async_stream_nolink, enumerable, {module, func, args, opts}, attrs}
    )
  end

  def async_stream_nolink(enum, args, attrs) do
    raise ArgumentError,
          """
          Invalid args. 
            enum: #{inspect(enum)}
            args: #{inspect(args)}
            attrs: #{inspect(attrs)}
          """
  end

  @spec stream_sync(Enumerable.t(), {module(), atom(), list(), Keyword.t()}, map()) ::
          Enumerable.t()
  def stream_sync(enumerable, {module, func, args, opts}, attrs) do
    GenServer.call(
      __MODULE__,
      {:stream, enumerable, {module, func, args, opts}, attrs}
    )
  end

  # Callbacks

  def init(_) do
    Process.send_after(self(), :discard_outdated, @discard_interval)
    {:ok, %{tasks: %{}}}
  end

  # ~~~~~~~~~~~~~~ CAST handlers ~~~~~~~~~~~~~~

  # Handle async stream with a list of anonymous functions
  def handle_cast({:async_stream, funcs, attrs}, %{tasks: tasks} = state) do
    task_state =
      make_stream(funcs, {__MODULE__, :async_stream, []}, attrs)

    new_tasks = Map.put(tasks, task_state.stream.ref, task_state)
    new_state = broadcast(%{state | tasks: new_tasks})

    Task.start(fn ->
      TaskOverlord.TaskSupervisor
      |> Task.Supervisor.async_stream(
        funcs,
        fn fun -> fun.() end,
        default_stream_opts([])
      )
      |> Enum.each(fn
        {:ok, result} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:ok, result}})

        {:exit, reason} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:error, reason}})
      end)

      GenServer.cast(__MODULE__, {:stream_complete, task_state.stream.ref})
    end)

    {:noreply, new_state}
  end

  # Handle async stream with no arguments
  def handle_cast(
        {:async_stream, enumerable, {module, func, [], opts}, heading, message},
        %{tasks: tasks} = state
      ) do
    task_state = make_stream(enumerable, {module, func, []}, heading, message)
    new_tasks = Map.put(tasks, task_state.stream.ref, task_state)
    new_state = broadcast(%{state | tasks: new_tasks})

    Task.start(fn ->
      TaskOverlord.TaskSupervisor
      |> Task.Supervisor.async_stream(
        enumerable,
        fn _element -> apply(module, func, []) end,
        default_stream_opts(opts)
      )
      |> Enum.each(fn
        {:ok, result} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:ok, result}})

        {:exit, reason} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:error, reason}})
      end)

      GenServer.cast(__MODULE__, {:stream_complete, task_state.stream.ref})
    end)

    {:noreply, new_state}
  end

  # Handle async stream with arguments
  def handle_cast(
        {:async_stream, enumerable, {module, func, args, opts}, heading, message},
        %{tasks: tasks} = state
      ) do
    task_state = make_stream(enumerable, {module, func, args}, heading, message)
    new_tasks = Map.put(tasks, task_state.stream.ref, task_state)
    new_state = %{state | tasks: new_tasks}

    Task.start(fn ->
      TaskOverlord.TaskSupervisor
      |> Task.Supervisor.async_stream(
        enumerable,
        fn element -> apply(module, func, [element | args]) end,
        default_stream_opts(opts)
      )
      |> Enum.each(fn
        {:ok, result} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:ok, result}})

        {:exit, reason} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:error, reason}})
      end)

      GenServer.cast(__MODULE__, {:stream_complete, task_state.stream.ref})
    end)

    {:noreply, broadcast(new_state)}
  end

  # Handle async stream with a list of anonymous functions
  def handle_cast({:async_stream_nolink, funcs, heading, message}, %{tasks: tasks} = state) do
    task_state =
      make_stream(funcs, {__MODULE__, :async_stream, []}, heading, message)

    new_tasks = Map.put(tasks, task_state.stream.ref, task_state)
    new_state = broadcast(%{state | tasks: new_tasks})

    Task.start(fn ->
      TaskOverlord.TaskSupervisor
      |> Task.Supervisor.async_stream_nolink(
        funcs,
        fn fun -> fun.() end,
        default_stream_opts([])
      )
      |> Enum.each(fn
        {:ok, result} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:ok, result}})

        {:exit, reason} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:error, reason}})
      end)

      GenServer.cast(__MODULE__, {:stream_complete, task_state.stream.ref})
    end)

    {:noreply, new_state}
  end

  # Handle async stream with no arguments
  def handle_cast(
        {:async_stream_nolink, enumerable, {module, func, [], opts}, heading, message},
        %{tasks: tasks} = state
      ) do
    task_state = make_stream(enumerable, {module, func, []}, heading, message)
    new_tasks = Map.put(tasks, task_state.stream.ref, task_state)
    new_state = broadcast(%{state | tasks: new_tasks})

    Task.start(fn ->
      TaskOverlord.TaskSupervisor
      |> Task.Supervisor.async_stream_nolink(
        enumerable,
        fn _element -> apply(module, func, []) end,
        default_stream_opts(opts)
      )
      |> Enum.each(fn
        {:ok, result} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:ok, result}})

        {:exit, reason} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:error, reason}})
      end)

      GenServer.cast(__MODULE__, {:stream_complete, task_state.stream.ref})
    end)

    {:noreply, new_state}
  end

  # Handle async stream with arguments
  def handle_cast(
        {:async_stream_nolink, enumerable, {module, func, args, opts}, heading, message},
        %{tasks: tasks} = state
      ) do
    task_state = make_stream(enumerable, {module, func, args}, heading, message)
    new_tasks = Map.put(tasks, task_state.stream.ref, task_state)
    new_state = %{state | tasks: new_tasks}

    Task.start(fn ->
      TaskOverlord.TaskSupervisor
      |> Task.Supervisor.async_stream_nolink(
        enumerable,
        fn element -> apply(module, func, [element | args]) end,
        default_stream_opts(opts)
      )
      |> Enum.each(fn
        {:ok, result} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:ok, result}})

        {:exit, reason} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:error, reason}})
      end)

      GenServer.cast(__MODULE__, {:stream_complete, task_state.stream.ref})
    end)

    {:noreply, broadcast(new_state)}
  end

  def handle_cast({:stream_complete, task_ref}, %{tasks: tasks} = state) do
    updated_task =
      tasks
      |> Map.get(task_ref)
      |> Map.update!(:stream, &Map.put(&1, :status, :done))
      |> Map.put(:finished_at, DateTime.utc_now())

    new_tasks = Map.put(tasks, task_ref, updated_task)
    new_state = %{state | tasks: new_tasks}
    {:noreply, broadcast(new_state)}
  end

  def handle_cast({:stream_item, task_ref, {:error, reason}}, %{tasks: tasks} = state) do
    Logger.error("#{__MODULE__} - Stream error: #{inspect(reason)}")

    updated_task =
      tasks
      |> Map.get(task_ref)
      |> Map.update!(:stream, &Map.put(&1, :status, :error))
      |> Map.put(:finished_at, DateTime.utc_now())
      |> Map.update!(:results, &(&1 ++ [{:error, reason}]))

    new_tasks = Map.put(tasks, task_ref, updated_task)
    new_state = %{state | tasks: new_tasks}
    {:noreply, broadcast(new_state)}
  end

  def handle_cast({:stream_item, task_ref, result}, %{tasks: tasks} = state) do
    task = Map.get(tasks, task_ref)

    updated_task =
      task
      |> Map.update!(:results, &(&1 ++ [result]))
      |> Map.update!(:stream_completed, &(&1 + 1))

    new_tasks = Map.put(tasks, task_ref, updated_task)
    new_state = %{state | tasks: new_tasks}
    {:noreply, broadcast(new_state)}
  end

  # ~~~~~~~~~~~~~~ CALL handlers ~~~~~~~~~~~~~~

  # Handle async stream with a list of anonymous functions
  def handle_call({:stream, funcs, attrs}, _from, %{tasks: tasks} = state)
      when is_list(funcs) do
    task_state = make_stream(funcs, {__MODULE__, :async_stream, []}, attrs)

    new_tasks = Map.put(tasks, task_state.stream.ref, task_state)
    new_state = broadcast(%{state | tasks: new_tasks})

    results =
      TaskOverlord.TaskSupervisor
      |> Task.Supervisor.async_stream(
        funcs,
        fn fun -> fun.() end,
        default_stream_opts([])
      )
      |> Enum.to_list()
      |> Enum.map(fn
        {:ok, result} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:ok, result}})
          {:ok, result}

        {:exit, reason} ->
          Logger.error("#{__MODULE__} - Stream error: #{inspect(reason)}")
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:error, reason}})
          {:exit, reason}
      end)

    GenServer.cast(__MODULE__, {:stream_complete, task_state.stream.ref})

    {:reply, results, new_state}
  end

  def handle_call(
        {:stream, enumerable, {module, func, args, opts}, attrs},
        _from,
        %{tasks: tasks} = state
      ) do
    task_state = make_stream(enumerable, {module, func, args}, attrs)
    new_tasks = Map.put(tasks, task_state.stream.ref, task_state)
    new_state = %{state | tasks: new_tasks}

    results =
      TaskOverlord.TaskSupervisor
      |> Task.Supervisor.async_stream(
        enumerable,
        fn element -> apply(module, func, [element | args]) end,
        default_stream_opts(opts)
      )
      |> Enum.to_list()
      |> Enum.map(fn
        {:ok, result} ->
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:ok, result}})
          {:ok, result}

        {:exit, reason} ->
          Logger.error("#{__MODULE__} - Stream error: #{inspect(reason)}")
          GenServer.cast(__MODULE__, {:stream_item, task_state.stream.ref, {:error, reason}})
          {:exit, reason}
      end)

    GenServer.cast(__MODULE__, {:stream_complete, task_state.stream.ref})

    {:reply, results, broadcast(new_state)}
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(
      TaskOverlordDemo.PubSub,
      @pub_sub_topic,
      {:task_overlord_updated, state}
    )

    state
  end

  defp default_stream_opts(opts) do
    Keyword.merge(
      [
        max_concurrency: 2,
        ordered: false,
        timeout: @default_timeout,
        on_timeout: :kill_task
      ],
      opts
    )
  end
end
