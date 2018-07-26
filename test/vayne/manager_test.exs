defmodule Vayne.ManagerTest do

  require Vayne.Cluster

  use ExUnit.Case, async: false

  setup_all do
    Application.ensure_all_started(:vayne)
    Process.sleep(3_000)
    on_exit "close application", fn -> Application.stop(:vayne) end
  end

  @target_group :groupA
  setup do
    on_exit "clean task group", fn -> Vayne.Manager.clean_task(@target_group) end
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

  def ensure_tasks_alive(tasks) do
    Enum.map(tasks, fn task ->
      pid = Vayne.Task.whereis_task(task)
      assert is_pid(pid) == true
      pid
    end)
  end

  test "push tasks" do

    #normal
    tasks = gen_task(10)
    assert {:ok, %{all: 10, already_registered: 0, diff: 0, error: 0, ok: 10}}
      = Vayne.Manager.push_task(@target_group, tasks)

    task_pids = ensure_tasks_alive(tasks)

    #diff
    {pids_new, pids_kill}   = Enum.split(task_pids, 8)
    {tasks_new, tasks_kill} = Enum.split(tasks, 8)
    assert {:ok, %{all: 8, already_registered: 8, diff: 2, error: 0, ok: 0}}
      = Vayne.Manager.push_task(@target_group, tasks_new)

    #should still alive
    tasks_new
    |> Enum.zip(pids_new)
    |> Enum.each(fn {task, pid} ->
      pid_t = Vayne.Task.whereis_task(task)
      assert pid == pid_t
    end)

    #should be killed
    tasks_kill
    |> Enum.zip(pids_kill)
    |> Enum.each(fn {task, pid} ->
      pid_t = Vayne.Task.whereis_task(task)
      assert pid_t == nil
      assert Process.alive?(pid) == false
    end)

    #more tasks
    tasks = gen_task(15)
    assert {:ok, %{all: 15, already_registered: 8, diff: 0, error: 0, ok: 7}}
      = Vayne.Manager.push_task(@target_group, tasks)

    task_pids = ensure_tasks_alive(tasks)
    assert {^pids_new, _} = Enum.split(task_pids, 8)

  end

  test "group not defined" do
    tasks = gen_task(10)
    assert {:error, "group is not defined"} = Vayne.Manager.push_task(:group_not_exist, tasks)
  end

end
