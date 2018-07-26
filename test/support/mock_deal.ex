defmodule Vayne.Export.Mock do
  @behaviour Vayne.Task.Export
  require Logger
  def run(%{parent: parent, ref: ref}, metrics) do
    send(parent, {ref, metrics})
    :ok
  end
  def run(_, _), do: :ok
end
