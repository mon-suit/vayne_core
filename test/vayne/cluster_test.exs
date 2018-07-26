defmodule Vayne.ClusterTest do

  require Vayne.Cluster

  use ExUnit.Case, async: false

  setup do
    nodes = Vayne.Cluster.spawn_nodes
    [n|_] = nodes
    :cover.start(nodes)
    on_exit "stop slave nodes", fn ->
      :cover.stop(nodes)
      :rpc.call(n, Vayne.Manager, :clean_task, [:groupA])
      Vayne.Cluster.stop_nodes(nodes)
    end
    %{nodes: nodes}
  end

  def gen_task(c) do
    Enum.map(1..c, fn i ->
      %Vayne.Task{
        uniqe_key:   "task-#{i}",
        interval:    10,
        metric_info: %{module: Vayne.Metric.Mock, params: nil},
        export_info:   %{module: Vayne.Export.Console, params: nil}
      }
    end)
  end

  def disconnect(src, nodes), do: :rpc.multicall(nodes, Node, :disconnect, [src])
  def connect(src, nodes),    do: :rpc.multicall(nodes, Node, :ping, [src])

  def running_tasks(nodes) do
    nodes
    |> List.wrap
    |> Enum.map(fn n -> %{groupA: tasks} = :rpc.call(n, Vayne.Manager, :local_tasks, []); tasks end)
    |> List.flatten
  end

  test "normal tasks", %{nodes: nodes} do
    tasks = gen_task(10)

    [node|other] = nodes

    #push tasks
    ok_count = nodes
    |> Enum.map(fn n -> 
      {:ok, %{ok: ok}} = :rpc.call(n, Vayne.Manager, :push_task, [:groupA, tasks])
       ok
    end)
    |> Enum.sum

    assert length(tasks) == ok_count

    #Node all connected

    tasks_partial = running_tasks(node)
    tasks_all = running_tasks(nodes)

    assert length(tasks) > length(tasks_partial)
    assert length(tasks) == length(tasks_all)

    #Node disconnect
    disconnect(node, other)

    Process.sleep(1_000)

    tasks_failover = running_tasks(node)
    tasks_other =  running_tasks(other)

    assert length(tasks) == length(tasks_failover)
    assert length(tasks) == length(tasks_other)

    #Node recover
    connect(node, other)
    
    Process.sleep(1_000)

    tasks_takeover = running_tasks(nodes)
    assert length(tasks) == length(tasks_takeover)
  end
  
end
