defmodule Vayne.Deal.Console do

  @behaviour Vayne.Task.Deal
  require Logger
  def run(params, metrics) do
    Logger.info "[Mock Deal] params: #{inspect params}, metrics: #{inspect metrics}"
  end

end
