defmodule Vayne.Metric.Port do
  @behaviour Vayne.Task.Metric

  @moduledoc """
  Check remote port is open:
  port.open = 1
  """

  @default %{"timeout" => 5_000, "type" => "tcp"}

  @doc """
  Init metric plugin.

  * `address`: hostname or ip.
  * `port`: port.
  * `type`: now only support "tcp". "udp" may implement in the future. Default "tcp".
  * `timeout`: timeout in milliseconds. Default 5_000 ms.

  ## Examples
  
      iex> Vayne.Metric.Port.init(%{"address" => "www.google.com"})       
      {:error, "port is missing"}

      iex> Vayne.Metric.Port.init(%{"port" => 80})                                
      {:error, "address is needed"}

      iex> Vayne.Metric.Port.init(%{"address" => "www.google.com", "port" => 80})
      {:ok,
       %{
         "address" => "www.google.com",
         "port" => 80,
         "timeout" => 5000,
         "type" => "tcp"
       }}

      iex> Vayne.Metric.Port.init(%{"address" => "8.8.8.8", "port" => 53})
      {:ok, %{"address" => "8.8.8.8", "port" => 53, "timeout" => 5000, "type" => "tcp"}}

  """
  def init(params) do
    stat = Map.merge(params, @default)
    has_need = Enum.any?(~w(address), fn x -> not is_nil(stat[x]) end)
    missing = Enum.filter(~w(port timeout), fn x -> stat[x] == nil end)

    cond do
      not has_need        -> {:error, "address is needed"}
      length(missing) > 0 -> {:error, "#{Enum.join(missing, ",")} is missing"}
      true                ->
        port = stat["port"]
        port = if is_binary(port), do: String.to_integer(port), else: port
        stat = Map.put(stat, "port", port)
        {:ok, stat}
    end
  end

  def run(stat = %{"type" => type}, log_func) do
    case type do
      "tcp" -> tcp_check(stat, log_func)
      #"udp" -> udp_check(stat, log_func)
      _     -> raise "type `#{type}` not support"
    end
  end
  def tcp_check(%{"address" => address, "port" => port, "timeout" => timeout}, log_func) do
    start = :os.system_time(:millisecond)

    ret =
      :gen_tcp.connect(
        to_charlist(address),
        port,
        [:binary, packet: 0, active: false, keepalive: true],
        timeout
      )

    using = :os.system_time(:millisecond) - start

    metrics =
      case ret do
        {:ok, sock} ->
          :gen_tcp.close(sock)
          %{"remote.check.port" => 1, "remote.check.port.using" => using}
        {:error, err} ->
          log_func.("connect fail: #{inspect(err)}")
          %{"remote.check.port" => -1, "remote.check.port.using" => using}
      end

    {:ok, metrics}
  end

  #def udp_check(%{"address" => address, "port" => port, "timeout" => timeout}, log_func)  do
  #  raise "not implement yet"
  #end

  def clean(_stat), do: :ok
end
