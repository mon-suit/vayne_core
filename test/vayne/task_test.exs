defmodule Vayne.TaskTest do

  require Vayne.Cluster

  use ExUnit.Case, async: true

  setup_all do
    Application.ensure_all_started(:vayne)
    Process.sleep(3_000)
    on_exit "close application", fn -> 
      Application.stop(:vayne)
    end
  end

  def spawn_task(task) do
    on_exit "clean task#{task.uniqe_key}", fn -> Vayne.Task.kill_task(task) end
    Vayne.Task.spawn_task(:groupA, task)
  end

  test "normal task" do
    ref = make_ref()
    task = %Vayne.Task{
      uniqe_key:   "normal task",
      interval:    10,
      metric_info: %{module: Vayne.Metric.Mock, params: nil},
      deal_info:   %{module: Vayne.Deal.Mock, params: %{parent: self(), ref: ref}}
    }

    assert :ok = spawn_task(task)

    assert_receive {^ref, %{"bar" => _, "baz" => _, "foo" => _}}, 5_000
  end

  test "timeout task" do
    task = %Vayne.Task{
      uniqe_key:   "timeout task",
      interval:    5,
      metric_info: %{module: Vayne.Metric.MockTimeout, params: nil},
      deal_info:   %{module: Vayne.Deal.Mock, params: %{parent: self(), ref: make_ref()}}
    }
    assert :ok = spawn_task(task)
    Process.sleep(7_000)

    {:ok, [{"timeout task", msg, _}]} = Vayne.Error.query_key(task.uniqe_key)
    assert msg =~ ~r/^Timeout!/
  end

  test "error task" do
    task = %Vayne.Task{
      uniqe_key:   "raise error task",
      interval:    5,
      metric_info: %{module: Vayne.Metric.MockRaise, params: nil},
      deal_info:   %{module: Vayne.Deal.Mock, params: %{parent: self(), ref: make_ref()}}
    }

    assert :ok = spawn_task(task)

    Process.sleep(6_000)

    {:ok, errors} = Vayne.Error.query_key(task.uniqe_key)
    
    {"raise error task", msg, _} = List.first(errors)

    assert msg =~ ~r/^task down unusual:.*raise some error/

  end

end
