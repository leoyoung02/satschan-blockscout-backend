# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# By default, the umbrella project as well as each child
# application will require this configuration file, ensuring
# they all use the same configuration. While one could
# configure all applications here, we prefer to delegate
# back to each application for organization purposes.
import_config "../apps/*/config/config.exs"

config :logger,
  backends: [
    # all applications and all levels
    :console,
    # all applications, but only errors
    {LoggerFileBackend, :error},
    # only :ecto, but all levels
    {LoggerFileBackend, :ecto},
    # only :block_scout_web, but all levels
    {LoggerFileBackend, :block_scout_web},
    # only :ethereum_jsonrpc, but all levels
    {LoggerFileBackend, :ethereum_jsonrpc},
    # only :explorer, but all levels
    {LoggerFileBackend, :explorer},
    # only :indexer, but all levels
    {LoggerFileBackend, :indexer},
    {LoggerFileBackend, :indexer_token_balances}
  ]

config :logger, :console,
  # Use same format for all loggers, even though the level should only ever be `:error` for `:error` backend
  format: "$time $metadata[$level] $message\n",
  metadata: [:application, :request_id]

config :logger, :ecto,
  # Use same format for all loggers, even though the level should only ever be `:error` for `:error` backend
  format: "$time $metadata[$level] $message\n",
  metadata: [:application, :request_id],
  metadata_filter: [application: :ecto]

config :logger, :error,
  # Use same format for all loggers, even though the level should only ever be `:error` for `:error` backend
  format: "$time $metadata[$level] $message\n",
  level: :error,
  metadata: [:application, :request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
