use Mix.Config

#config :logger, backends: []

config :libring,
  rings: [
    ring_vayne: 
    [
      monitor_nodes: true,
      node_blacklist: [~r/^remsh.*$/, "primary@127.0.0.1"]
    ]
  ]

#config :logger,
#  level: :info,
#  handle_otp_reports: true,
#  handle_sasl_reports: true

#config :logger, :console,
#  format: "$date $time $metadata[$level] $levelpad$message\n",
#  metadata: [:application, :module, :function, :pid]

config :vayne, error: %{
  module: Vayne.Error.Ets,
  keep_count: 10,
  keep_time: 2 * 24 * 60 * 60 # 2 days
}

config :vayne, groups: [:groupA, :groupB]
