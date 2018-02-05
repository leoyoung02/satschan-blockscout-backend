use Mix.Config

# For production, we often load configuration from external
# sources, such as your system environment. For this reason,
# you won't find the :http configuration below, but set inside
# ExplorerWeb.Endpoint.init/2 when load_from_system_env is
# true. Any dynamic configuration should be done there.
#
# Don't forget to configure the url host to something meaningful,
# Phoenix uses this information when generating URLs.
#
# Finally, we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the mix phx.digest task
# which you typically run after static files are built.
config :explorer, ExplorerWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  instrumenters: [NewRelixir.Instrumenters.Phoenix],
  load_from_system_env: true,
  pubsub: [adapter: Phoenix.PubSub.Redis, url: System.get_env("REDIS_URL"), node_name: System.get_env("DYNO")],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  url: [scheme: "https", host: Map.fetch!(System.get_env(), "HEROKU_APP_NAME") <> ".herokuapp.com", port: 443]

# Do not print debug messages in production
config :logger, level: :info

# Configures the database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: String.equivalent?(System.get_env("ECTO_USE_SSL") || "true", "true"),
  prepare: :unnamed,
  timeout: 60_000,
  pool_timeout: 60_000

# Configure New Relic
config :new_relixir,
  application_name: System.get_env("NEW_RELIC_APP_NAME"),
  license_key: System.get_env("NEW_RELIC_LICENSE_KEY")

# Configure Web3
config :ethereumex,
  scheme: System.get_env("ETHEREUM_SCHEME"),
  host: System.get_env("ETHEREUM_HOST"),
  port: System.get_env("ETHEREUM_PORT")

# Configure Quantum
config :explorer, Explorer.Scheduler,
  jobs: [
    [schedule: {:extended, "* * * * * *"}, task: {Explorer.Workers.ImportBlock, :perform_later, ["latest"]}],
    [schedule: {:extended, "*/15 * * * * *"}, task: {Explorer.Workers.ImportSkippedBlocks, :perform_later, [String.to_integer(System.get_env("EXPLORER_BACKFILL_CONCURRENCY") || "1")]}],
  ]

# Configure Exq
config :exq,
  concurrency: String.to_integer(System.get_env("EXQ_CONCURRENCY") || "1"),
  node_identifier: Explorer.ExqNodeIdentifier,
  url: System.get_env("REDIS_URL")
