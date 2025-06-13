defmodule TaskOverlordDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TaskOverlordDemoWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:task_overlord_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TaskOverlordDemo.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: TaskOverlordDemo.Finch},
      # Start a worker by calling: TaskOverlordDemo.Worker.start_link(arg)
      # {TaskOverlordDemo.Worker, arg},
      # Start to serve requests, typically the last entry
      TaskOverlordDemoWeb.Endpoint,
      {Task.Supervisor, name: TaskOverlord.TaskSupervisor},
      {TaskOverlordDemo.Overlord.Task, []},
      {TaskOverlordDemo.Overlord.Stream, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TaskOverlordDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TaskOverlordDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
