defmodule Vayne.Error.EtsTest do
  use ExUnit.Case, async: false

  alias Vayne.Error

  @keep_time 5
  @default_opt %{module: Vayne.Error.Ets, keep_count: 3, keep_time: @keep_time}

  setup_all do
    Application.put_env(:vayne, :error, @default_opt)
    Application.ensure_all_started(:libring)

    {:ok, pid} = Vayne.Error.start_link

    task_key = "FakeTaskTestVayneError"

    on_exit "close Vayne", fn ->
      Application.stop(:libring)
      Process.exit(pid, :killed)
    end

    %{task_key: task_key}
  end

  test "test push_error and query_key", %{task_key: task_key} do

    msgs = ["mmmmmmmmmmmmmm", "asdfasdfefef", "12312csfwa4123"]

    Enum.each(msgs, &(Error.push_error(task_key, &1)))

    {:ok, records} = Error.query_key(task_key)

    all_msgs = Enum.map(records, fn {^task_key, msg, _time} -> msg end)

    Enum.each(msgs, &(assert &1 in all_msgs))
    
  end

  test "keep count", %{task_key: task_key} do
    Enum.each(1..10, fn x -> Error.push_error(task_key, "#{x}11111") end)
    {:ok, records} = Error.query_key(task_key)
    assert length(records) >= 10
    Error.clean()
    {:ok, records} = Error.query_key(task_key)
    assert length(records) == 3
  end

  test "keep time", %{task_key: task_key} do
    Enum.each(1..10, fn x -> Error.push_error(task_key, "#{x}11111") end)
    {:ok, records} = Error.query_time(10)
    assert length(records) >= 0

    seconds = (@keep_time + 3)
    seconds |> :timer.seconds |> Process.sleep

    Error.clean()
    {:ok, records} = Error.query_key(task_key)
    assert Enum.empty?(records) == true
  end

end
