defmodule Vayne.Manager do

  #Public API
  def push_task(group, tasks), do: GenServer.call(__MODULE__, {:push_task, {group, tasks}})
  def clean_task(group),       do: GenServer.call(__MODULE__, {:push_task, {group, []}})

  def local_tasks(group \\ :_) do
    group_tasks = Registry.match(Vayne.Task.GroupRegistry, :group, {group, :_})
    group_tasks
    |> Enum.reduce(%{}, fn ({pid, {group, k}}, acc) ->
      array = acc[group] || []
      array = [{k, pid} | array]
      Map.put(acc, group, array)
    end)
  end

  #Private
  require Logger

  def start_link do
    GenServer.start(__MODULE__, nil, name: __MODULE__)
  end

  @default_module Vayne.Store.File
  def init(_) do
    groups = Application.get_env(:vayne, :groups)
    store  = Application.get_env(:vayne, :store, @default_module)
    :ok    = store_init(store, groups)

    :ok = :net_kernel.monitor_nodes(true, [node_type: :all])

    #wait node connect
    Process.send_after(self(), :load_task, :timer.seconds(3))

    {:ok, {groups, store}}
  end

  def handle_info({:nodeup, node, _info}, state) do
    killed = kill_tasks_with_ring()
    Logger.info "Node #{inspect node} up, kill task: #{killed}"
    {:noreply, state}
  end

  def handle_info({:nodedown, node, _info}, state) do
    send(self(), :load_task)
    {:noreply, state}
  end

  def handle_info(:load_task, stat = {groups, store}) do
    Enum.each(groups, fn group ->
      with {:ok, tasks}    <- store_get_task(store, group),
                 tasks     <- filter_tasks_with_ring(tasks),
                 statistic <- spawn_tasks(group, tasks)
      do
        Logger.info "Load task group #{group} from store #{store}: #{inspect statistic}"
      else
        {:error, error} ->
          Logger.error "Load task group #{group} from store #{store}: #{inspect error}"
        error ->
          Logger.error "Load task group #{group} from store #{store}: #{inspect error}"
      end
    end)
    {:noreply, stat}
  end

  def handle_call({:push_task, {group, tasks}}, _from, stat = {groups, store}) do
    if group in groups do
      :ok        = store_save_task(store, group, tasks)
      tasks      = filter_tasks_with_ring(tasks)
      statistic  = spawn_tasks(group, tasks)
      diff       = diff_task(group, tasks)
      statistic  = Map.put(statistic, :diff, diff)
      {:reply, {:ok, statistic}, stat}
    else
      {:reply, {:error, "group is not defined"}, stat}
    end
  end

  defp store_init(store, groups),            do: apply(store, :init,      [groups])
  defp store_save_task(store, group, tasks), do: apply(store, :save_task, [group, tasks])
  defp store_get_task(store, group),         do: apply(store, :get_task,  [group])

  defp should_run?(uniqe_key) do
    node() == HashRing.Managed.key_to_node(Vayne.hash_ring(), uniqe_key)
  end

  defp filter_tasks_with_ring(tasks), do: Enum.filter(tasks, &(should_run?(&1.uniqe_key)))

  defp kill_tasks_with_ring do
    tasks = Registry.match(Vayne.Task.GroupRegistry, :group, {:_, :_})
    tasks
    |> Enum.filter(fn {_pid, {_group, k}} -> not should_run?(k) end)
    |> Enum.map(fn {pid, {_group, _k}} -> Vayne.Task.kill_task(pid) end)
    |> length
  end

  defp spawn_tasks(group, tasks) do
    statistic = %{ok: 0, error: 0, already_registered: 0}
    tasks
    |> Enum.map(fn task -> Vayne.Task.spawn_task(group, task) end)
    |> Enum.reduce(statistic, fn
      (x, acc) when is_atom(x) -> update_in(acc, [x], &(&1 + 1))
      ({:error, _}, acc)       -> update_in(acc, [:error], &(&1 + 1))
    end)
    |> Map.put(:all, length(tasks))
  end

  defp diff_task(group, tasks) do
    permit_keys = Enum.map(tasks, &(&1.uniqe_key))
    group_tasks = Registry.match(Vayne.Task.GroupRegistry, :group, {group, :_})
    group_tasks
    |> Enum.filter(fn {_pid, {_group, k}} -> not k in permit_keys end)
    |> Enum.map(fn {pid, {_group, _k}} -> Vayne.Task.kill_task(pid) end)
    |> length
  end

end
