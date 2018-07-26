#Learn from Swarm test helper. https://raw.githubusercontent.com/bitwalker/swarm/master/test/support/cluster.ex
defmodule Vayne.Cluster do
  
  @max_nodes 3
  def spawn_nodes() do
    first_node = :"primary@127.0.0.1"
    :net_kernel.start([first_node])
    nodes = 1..@max_nodes
    |> Enum.map(fn index -> "node-#{index}" end)
    |> Enum.map(fn name ->
      {:ok, node} = :slave.start(to_charlist("127.0.0.1"), String.to_atom(name))
      add_code_paths(node)
      transfer_configuration(node)
      ensure_applications_started(node)
      node
    end)

    Process.sleep(5_000)
    nodes
  end

  def stop_nodes(nodes) do
    Enum.each(nodes, fn node -> :ok = :slave.stop(node) end)
    Application.stop(:vayne)
    :net_kernel.stop
  end

  defp application_names do
    apps = Enum.map(Application.loaded_applications, fn {app_name, _, _} -> app_name end)
    apps ++ [:swarm, :vayne]
  end
  defp add_code_paths(node), do: :rpc.call(node, :code, :add_paths, [:code.get_path()])

  defp transfer_configuration(node) do
    for app_name <- application_names() do
      for {key, val} <- Application.get_all_env(app_name) do
        :rpc.call(node, Application, :put_env, [app_name, key, val])
      end
    end
  end

  defp ensure_applications_started(node) do
    :rpc.call(node, Application, :ensure_all_started, [:mix])
    :rpc.call(node, Application, :ensure_all_started, [:logger])

    #shutdown slave log
    :rpc.call(node, Logger, :remove_backend, [:console])

    :rpc.call(node, Mix, :env, [Mix.env()])

    for app_name <- application_names() do
      :rpc.call(node, Application, :ensure_all_started, [app_name])
    end
  end

end
