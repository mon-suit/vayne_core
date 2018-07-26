defmodule Vayne.Export.Console do

  @behaviour Vayne.Task.Export
  require Logger
  def run(params, metrics) do
    Logger.info "[Mock Export] params: #{inspect params}, metrics: #{inspect metrics}"
  end

end
