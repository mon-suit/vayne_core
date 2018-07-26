defmodule Vayne.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      {Registry, keys: :unique, name: Vayne.Task.NameRegistry},
      {Registry, keys: :duplicate, name: Vayne.Task.GroupRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Vayne.Task.Supervisor},
      {Task.Supervisor, name: :vayne_async_supervisor},
      worker(Vayne.Error, []),
      worker(Vayne.Manager, []),
    ]

    opts = [strategy: :one_for_one, name: Vayne.Application]
    Supervisor.start_link(children, opts)
  end
end
