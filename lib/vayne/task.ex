defmodule Vayne.Task.Metric do
  @moduledoc """
  """

  @type t :: %__MODULE__{module: module(), params: Vayne.Task.params}

  defstruct module: nil, params: %{}

  @type stat     :: any()
  @type log_func :: function()

  @callback init(Vayne.Task.params) :: {:ok, stat} | {:error, any()}
  @callback run(stat, log_func)     :: {:ok, Vayne.Task.metrics} | {:error, any()}
  @callback clean(stat)             :: :ok | {:error, any()}
end

defmodule Vayne.Task.Deal do
  @type t :: %__MODULE__{module: module(), params: map()}

  defstruct module: nil, params: %{}

  @callback run(Vayne.Task.params, Vayne.Task.metrics) :: :ok | {:error, any()}
end

defmodule Vayne.Task do

  @type params      :: map()
  @type metrics     :: map()

  alias Vayne.Error
  require Logger

  @type t :: %__MODULE__{
          uniqe_key:   binary(),
          interval:    pos_integer(),
          metric_info: Metric.t,
          deal_info:   Deal.t
        }

  defstruct uniqe_key:   nil,
            interval:    nil,
            metric_info: %Vayne.Task.Metric{},
            deal_info:   %Vayne.Task.Deal{}

  def whereis_task(%{uniqe_key: uniqe_key}), do: whereis_task(uniqe_key)
  def whereis_task(uniqe_key) when is_binary(uniqe_key) do
    GenServer.whereis(task_server_name(uniqe_key))
  end
  def whereis_task(_), do: nil
            #
            #  def kill_task(%{uniqe_key: uniqe_key}), do: kill_task(uniqe_key)
            #  def kill_task(uniqe_key) when is_binary(uniqe_key) do
            #    uniqe_key
            #    |> whereis_task()
            #    |> kill_task()
            #  end
  def kill_task(pid) when is_pid(pid), do: DynamicSupervisor.terminate_child(Vayne.Task.Supervisor, pid)
  def kill_task(_), do: nil

  def spawn_task(group, task = %Vayne.Task{}) do

    spec = %{id: task.uniqe_key, start: {Vayne.Task, :start_link, [group, task]}}

    case DynamicSupervisor.start_child(Vayne.Task.Supervisor, spec) do
      {:ok, pid} -> :ok
      {:error, {:already_registered, _pid}} -> :already_registered
      {:error, {:already_started, _pid}}    -> :already_registered
      {:error, reason} ->
        Error.push_error(task.uniqe_key, reason)
        {:error, reason}
      reason ->
        Error.push_error(task.uniqe_key, reason)
        {:error, reason}
    end

  end

  def test_task(task = %Vayne.Task{}, no_deal \\ true) do
    with {:ok, stat}    <- task_init(task),
         {:ok, metrics} <- task_metrics(task, stat)
    do
      if no_deal do
        {:ok, metrics}
      else
        task_deal(task, metrics)
      end
    else
      {:error, error} -> {:error, error}
      error           -> {:error, error}
    end
  end

  def start_link(group, task = %Vayne.Task{}) do
    GenServer.start_link(__MODULE__, [group, task], name: task_server_name(task.uniqe_key))
  end

  @gap_factor 0.7
  @init_doing %{async: nil, start_time: nil, count: nil}
  @init_error %{msg: nil, start_time: nil, count: nil}
  def init([group, task = %Vayne.Task{}]) do
    gap = :erlang.phash2(task, trunc(task.interval * @gap_factor))

    stat = %{
      task:         task,
      doing:        @init_doing,
      next_time:    :os.system_time(:seconds) + gap,
      last_error:   @init_error,
      all_counts:   0,
      error_counts: 0
    }

    case Registry.register(Vayne.Task.GroupRegistry, :group, {group, task.uniqe_key}) do
      {:error, error} ->
        {:stop, error}
      {:ok, _} ->
        send(self(), :schedule)
        {:ok, stat}
    end
  end

  @interval :timer.seconds(2)
  def handle_info(:schedule, stat) do
    new_stat = stat
    #|> yield_async()        #0. yield task & statistic task; This maybe useless.
    |> kill_async()          #1. reset task & stop timeout task
    |> start_async()         #2. start async_nolink task

    Process.send_after(self(), :schedule, @interval)
    {:noreply, new_stat}
  end

  def handle_info({ref_s, result}, stat = %{doing: %{async: %Task{ref: ref_t}}}) when ref_s == ref_t do
    new_stat = yield_async(stat, result)
    {:noreply, new_stat}
  end

  def handle_info({:DOWN, ref_s, _, _pid, reason}, stat = %{doing: %{async: %Task{ref: ref_t}}})
      when ref_s == ref_t do
    new_stat = if reason != :normal do
      yield_async(stat, "task down unusual: #{inspect reason}")
    else
      stat
    end
    {:noreply, new_stat}
  end

  def handle_info({:swarm, :die}, stat) do
    {:stop, :shutdown, stat}
  end

  def handle_info(msg, stat) do
    Logger.warn "receive unrecognized msg: #{inspect msg}"
    {:noreply, stat}
  end

  def handle_call({:swarm, :begin_handoff}, _from, stat = %{task: task}) do
    Logger.info "task #{task.uniqe_key} should handoff!"
    {:reply, :restart, stat}
  end

  defp yield_async(stat = %{task: task, doing: %{start_time: start_time, count: count}}, result) do
    error = case result do
      :ok              -> nil
      {:error, reason} -> reason
      reason           -> reason
    end
    if error do
      Error.push_error(task.uniqe_key, error)
      last_error = %{
        @init_error | msg: error,
        start_time: start_time, count: count
      }
      error_counts = stat.error_counts + 1
      stat
      |> Map.put(:last_error, last_error)
      |> Map.put(:error_counts, error_counts)
    else
      stat
    end
  end

  @timeout_threshold 0.7
  defp kill_async(stat = %{doing: %{async: async}}) when is_nil(async), do: stat
  defp kill_async(stat = %{task: task = %Vayne.Task{}, doing: %{async: async = %Task{}, start_time: start_time}}) do
    timeout_time = task.interval * @timeout_threshold + start_time
    now          = :os.system_time(:seconds)

    if now > timeout_time do
      Task.shutdown(async, :brutal_kill)
      Error.push_error(task.uniqe_key, "Timeout! start_time: #{start_time}, timeout_time: #{timeout_time}, now: #{now}")
    end

    if not Process.alive?(async.pid) do
      Map.put(stat, :doing, @init_doing)
    else
      stat
    end
  end

  defp start_async(stat = %{doing: %{async: async}}) when not is_nil(async), do: stat
  defp start_async(stat = %{task: task = %Vayne.Task{}, next_time: next_time, all_counts: all_counts}) do
    now = :os.system_time(:seconds)
    if now > (next_time - min(2, @interval)) do
      all_counts = all_counts + 1
      next_time  = now + task.interval

      async = Task.Supervisor.async_nolink(
        :vayne_async_supervisor,
        fn -> task_run(task) end
      )

      doing = %{@init_doing | async: async, start_time: now, count: all_counts}

      stat
      |> Map.put(:doing, doing)
      |> Map.put(:all_counts, all_counts)
      |> Map.put(:next_time, next_time)
    else
      stat
    end
  end

  defp task_run(task) do
    with {:ok, stat}    <- task_init(task),
         {:ok, metrics} <- task_metrics(task, stat),
         :ok            <- task_deal(task, metrics)
    do
      :ok
    else
      {:error, error} -> {:error, error}
      error           -> {:error, error}
    end
  end

  defp task_init(%{metric_info: %{module: m, params: a}}), do: apply(m, :init, [a])

  defp task_metrics(%{uniqe_key: key, metric_info: %{module: m}}, stat) do
    log_func = fn msg -> Error.push_error(key, msg) end
    ret = case apply(m, :run, [stat, log_func]) do
      result = {:ok, _}    -> result
      result = {:error, _} -> result
      error                -> {:error, error}
    end

    case apply(m, :clean, [stat]) do
      {:error, msg} -> Error.push_error(key, msg)
      _             -> nil
    end

    ret
  end

  defp task_deal(%{deal_info: %{module: m, params: a}}, metrics), do: apply(m, :run, [a, metrics])

  defp task_server_name(uniqe_key), do: {:via, Registry, {Vayne.Task.NameRegistry, uniqe_key}}
end
