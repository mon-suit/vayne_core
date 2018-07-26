defmodule Vayne.MixProject do
  use Mix.Project

  def project do
    [
      app: :vayne,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Vayne.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:libring, "~> 1.3"},
      #{:io_ansi_table, "~> 0.4.13"},
      {:io_ansi_table, git: "https://github.com/milkwine/io_ansi_table", branch: "support_remote_shell"},
      {:excoveralls, "~> 0.8", only: :test},
      {:credo, "~> 0.9", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
