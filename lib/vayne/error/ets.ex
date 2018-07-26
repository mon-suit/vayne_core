defmodule Vayne.Error.Ets do

  @behaviour Vayne.Error

  #Public API
  def clean,                 do: GenServer.call(__MODULE__, :clean)

  def query_key(key),        do: GenServer.call(__MODULE__, {:query_key, key})

  def query_time(seconds),   do: GenServer.call(__MODULE__, {:query_time, seconds})

  def push_error(key, msg, timestamp), do: GenServer.cast(__MODULE__, {:push, key, msg, timestamp})

  def start_link(params) do
    GenServer.start_link(__MODULE__, params, name: __MODULE__)
  end

  #Private
  def init(params) do
    params = Map.take(params, [:keep_count, :keep_time])
    table  = :ets.new(:vayne_error_ets, [:bag, :protected, :named_table])
    schedule_clean()
    {:ok, {table, params}}
  end

  def handle_call({:query_key, key}, _from, stat = {table, _params}) do
    ret = :ets.lookup(table, key)
    {:reply, {:ok, ret}, stat}
  end

  def handle_call({:query_time, seconds}, _from, stat = {table, _params}) do
    timestamp = :os.system_time(:seconds) - seconds
    pattern   = [{{:"$1", :"$2", :"$3"}, [{:>, :"$3", timestamp}], [:"$_"]}]
    ret       = :ets.select(table, pattern)
    {:reply, {:ok, ret}, stat}
  end

  def handle_call(:clean, _from, stat) do
    clean(stat)
    {:reply, :ok, stat}
  end

  def handle_cast({:push, key, msg, time}, stat = {table, _params}) do
    :ets.insert(table, {key, msg, time})
    {:noreply, stat}
  end

  def handle_info(:schedule_clean, stat) do
    clean(stat)
    schedule_clean()
    {:noreply, stat}
  end

  defp clean({table, %{keep_time: keep_time, keep_count: keep_count}}) do
    #clean keep_time
    timestamp = :os.system_time(:seconds) - keep_time
    pattern   = [{{:"$1", :"$2", :"$3"}, [{:<, :"$3", timestamp}], [true]}]
    _del      = :ets.select_delete(table, pattern)

    #clean keep_count
    keys_pattern = [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}]
    keys = table |> :ets.select(keys_pattern) |> Enum.uniq

    Enum.each(keys, fn key ->
      table
      |> :ets.lookup(key)
      |> Enum.slice(keep_count..-1)
      |> Enum.each(&(:ets.delete_object(table, &1)))
    end)
  end

  @interval :timer.minutes(3)
  defp schedule_clean, do: Process.send_after(self(), :schedule_clean, @interval)
end
