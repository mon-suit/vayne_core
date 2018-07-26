defmodule Vayne.Debug do

  def all_task do
    {res, _bad_nodes} = :rpc.multicall(Vayne.server_nodes(), Vayne.Manager, :local_tasks, [])
    res
    |> Enum.map(&Map.to_list/1)
    |> List.flatten
    |> Enum.reduce(%{}, fn({g, tasks}, acc) ->
      array = acc[g] || []
      array = array ++ tasks
      Map.put(acc, g, array)
    end)
  end

  def statistic_task do
    all_task()
    |> Map.to_list
    |> Enum.map(fn {k, tasks} -> {k, length(tasks)} end)
    |> Enum.into(%{})
  end

  @recent_seconds :timer.minutes(5)
  def statistic_error(time \\ @recent_seconds) do
    {:ok, errors} = Vayne.Error.query_time(time)
    Enum.reduce(errors, %{}, fn ({key, _error, _time}, acc) ->
      Map.update(acc, key, 1, &(&1 + 1))
    end)
  end

  @max_width 40
  @table_headers [:uniqe_key, :all_counts, :error_counts, :next_time, :metric, :export, :last_error]
  def info_tasks, do: info_tasks(match: "")
  def info_tasks(opts) do
    max_width = Keyword.get(opts, :max_width, @max_width)
    status = query_task(opts)
    unless Enum.empty?(status) do
      status = trim_task_status(status)
      count = length(status)
      IO.ANSI.Table.format(status, headers: @table_headers, max_width: max_width, style: :barish, count: count)
      IO.puts "count: #{count}"
    end
  end

  def task_status(uniqe_key) when is_binary(uniqe_key) do
    {res, _bad_nodes} = :rpc.multicall(Vayne.server_nodes(), Vayne.Task, :whereis_task, [uniqe_key])
    res
    |> Enum.find(&is_pid/1)
    |> task_status()
  end

  def task_status(pid) when is_pid(pid), do: :sys.get_state(pid)

  def task_status(_pid), do: nil

  def query_task(opts) do
    tasks = all_task()

    tasks = if opts[:group] do
      Map.get(tasks, opts[:group], [])
    else
      tasks |> Map.values |> List.flatten
    end

    tasks = if opts[:match] do
      Enum.filter(tasks, fn {k, _pid} -> k =~ opts[:match] end)
    else
      tasks
    end

    Enum.map(tasks, fn {_k, pid} -> task_status(pid) end)
  end

  defp trim_task_status(status) when is_list(status), do: Enum.map(status, &(trim_task_status(&1)))
  defp trim_task_status(status) do

    ret        = Map.take(status, [:all_counts, :error_counts, :next_time])
    last_error = status.last_error

    last_error_msg = if last_error != nil and last_error[:start_time] != nil do
      until = :os.system_time(:seconds) - last_error[:start_time]
      "#{until}s ago: #{inspect last_error[:msg]}"
    else
      ""
    end

    task = status.task
    ret
    |> Map.put(:last_error, last_error_msg)
    |> Map.put(:uniqe_key,  task.uniqe_key)
    |> Map.put(:metric,     task.metric_info[:module])
    |> Map.put(:export,     task.export_info[:module])
  end

end
