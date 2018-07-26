defmodule Vayne.Metric.Mock do
  @behaviour Vayne.Task.Metric

  def init(_params), do: {:ok, nil}

  def run(_stat, _log_func) do
    {:ok, %{
      "foo" => :rand.uniform(100),
      "bar" => :rand.uniform(100),
      "baz" => :rand.uniform(100),
    }}
  end

  def clean(_stat), do: :ok

end

defmodule Vayne.Metric.MockTimeout do
  @behaviour Vayne.Task.Metric

  def init(_params), do: {:ok, nil}

  def run(_stat, _log_func) do
    Process.sleep(100_000)
    {:ok, %{
      "foo" => :rand.uniform(100),
      "bar" => :rand.uniform(100),
      "baz" => :rand.uniform(100),
    }}
  end

  def clean(_stat), do: :ok
end

defmodule Vayne.Metric.MockRaise do
  @behaviour Vayne.Task.Metric

  def init(_params), do: {:ok, nil}

  def run(_stat, _log_func) do
    raise "raise some error"
    {:ok, %{
      "foo" => :rand.uniform(100),
      "bar" => :rand.uniform(100),
      "baz" => :rand.uniform(100),
    }}
  end

  def clean(_stat), do: :ok
end
