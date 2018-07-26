defmodule Vayne.Store.FileTest do
  use ExUnit.Case

  def gen_tasks(count) do
    1..count |> Enum.map(fn _ ->
      %Vayne.Task{
        uniqe_key:   "test_task##{:rand.uniform(1000)}",
        interval:    10,
        metric_info: %{module: Vayne.Metric.Port, params: %{"ip" => "127.0.0.1", "port" => 999}},
        deal_info:   %{module: Vayne.Deal.Console, params: nil}
      }
    end)
  end

  @test_group :group_test

  setup_all do
    Vayne.Store.File.init([@test_group])
    dir = Vayne.Store.File.group_dir(@test_group)
    on_exit "clean group_test", fn -> File.rm_rf!(dir) end
  end

  test "test normal save" do
    tasks = gen_tasks(10)
    :ok = Vayne.Store.File.save_task(@test_group, tasks)

    {:ok, tasks_get} = Vayne.Store.File.get_task(@test_group)

    assert tasks == tasks_get
  end

  test "test rotate" do
    Enum.each(1..10, fn _ ->
      tasks = gen_tasks(10)
      Vayne.Store.File.save_task(@test_group, tasks)
    end)

    tasks = gen_tasks(10)
    Vayne.Store.File.save_task(@test_group, tasks)
    {:ok, tasks_get} = Vayne.Store.File.get_task(@test_group)
    assert tasks == tasks_get

    files = @test_group
      |> Vayne.Store.File.group_dir()
      |> Path.join("/*")
      |> Path.wildcard()

    assert length(files) == 6 # task + task.x * 5
  end

end
