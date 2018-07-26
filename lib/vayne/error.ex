defmodule Vayne.Error do

  require Logger

  @type key       :: binary() | atom()
  @type msg       :: binary()
  @type seconds   :: non_neg_integer
  @type timestamp :: non_neg_integer

  @callback clean                           :: :ok          | {:error, any()}
  @callback push_error(key, msg, timestamp) :: :ok          | {:error, any()}
  @callback query_key(key)                  :: {:ok, [msg]} | {:error, any()}
  @callback query_time(key)                 :: {:ok, [msg]} | {:error, any()}

  @default_keep %{keep_count: 10, keep_time: 2 * 24 * 60 * 60}
  @default_error %{module: Vayne.Error.Ets} |> Map.merge(@default_keep)

  def start_link do
    error            = Application.get_env(:vayne, :error, @default_error)
    {module, params} = Map.pop(error, :module)
    params           = Map.merge(@default_keep, params)
    apply(module, :start_link, [params])
  end

  def clean, do: apply(error_module(), :clean, [])

  def push_error(key, msg) do
    Logger.error "[#{inspect key}]: #{inspect msg}"
    now   = :os.system_time(:seconds)
    apply(error_module(), :push_error, [key, msg, now])
  end

  def query_key(key) do
    local_node = node()
    case HashRing.Managed.key_to_node(Vayne.hash_ring(), key) do
      ^local_node -> apply(error_module(), :query_key, [key])
      remote_node -> :rpc.call(remote_node, __MODULE__, :query_key, [key])
    end
  end

  def query_time(seconds) do
    nodes = Node.list ++ [node()]
    {result, _bad} = :rpc.multicall(nodes, error_module(), :query_time, [seconds])
    result = Enum.reduce(result, [], fn
      ({:ok, ret}, acc) -> acc ++ ret
      (_, acc)          -> acc
    end)
    {:ok, result}
  end

  def query_time_local(seconds), do: apply(error_module(), :query_time, [seconds])

  defp error_module do
    error = Application.get_env(:vayne, :error, @default_error)
    error.module
  end

end
