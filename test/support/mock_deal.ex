defmodule Vayne.Deal.Mock do
  @behaviour Vayne.Task.Deal
  require Logger
  def run(%{parent: parent, ref: ref}, metrics) do
    send(parent, {ref, metrics})
    :ok
  end
  def run(_, _), do: :ok
end
