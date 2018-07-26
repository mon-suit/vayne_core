defmodule Vayne do

  def hash_ring,    do: Application.get_env(:vayne, :ring, :ring_vayne)
  def server_nodes, do: HashRing.Managed.nodes(hash_ring())

  defdelegate statistic_task,           to: Vayne.Debug

  defdelegate statistic_error,          to: Vayne.Debug

  defdelegate statistic_error(seconds), to: Vayne.Debug

  defdelegate info_tasks,               to: Vayne.Debug
  defdelegate info_tasks(opts),         to: Vayne.Debug

  defdelegate error_recently(seconds),   to: Vayne.Error, as: :query_time

  defdelegate error_from_task(task_key), to: Vayne.Error, as: :query_key

end
