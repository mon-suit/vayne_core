defmodule Vayne.Metric.PortTest do
  use ExUnit.Case, async: false
  doctest Vayne.Metric.Port

  setup_all do
    :inet_gethost_native.start_link
    Process.sleep(2_000)
    :ok
  end

  setup do
    process_count = length(Process.list())
    port_count    = length(Port.list())
    ets_count     = length(:ets.all())
    on_exit "ensure release resource", fn ->
      assert process_count == length(Process.list())
      assert port_count    == length(Port.list())
      assert ets_count     == length(:ets.all())
    end
  end

  test "check tcp success" do
    {:ok, stat} = Vayne.Metric.Port.init(%{"address" => "www.google.com", "port" => 6379})

    assert {:ok, %{"remote.check.port" => 1, "remote.check.port.using" => _}}
      = Vayne.Metric.Port.run(stat, fn _msg -> :ok end)
  end

  test "check tcp fail" do
    {:ok, stat} = Vayne.Metric.Port.init(%{"address" => "127.0.0.1", "port" => 1234})

    assert {:ok, %{"remote.check.port" => -1, "remote.check.port.using" => _}}
      = Vayne.Metric.Port.run(stat, fn _msg -> :ok end)
  end

end
