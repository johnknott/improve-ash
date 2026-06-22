# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :improve,
  ash_domains: [Improve.Accounts, Improve.Plans, Improve.Sessions, Improve.Journal, Improve.Ai],
  ecto_repos: [Improve.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :improve, ImproveWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: ImproveWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Improve.PubSub,
  live_view: [signing_salt: "xWGOTrWn"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ash_typescript,
  output_file: "priv/generated/ash_rpc.ts",
  types_output_file: "priv/generated/ash_types.ts",
  run_endpoint: "/api/rpc/run",
  validate_endpoint: "/api/rpc/validate",
  input_field_formatter: :camel_case,
  output_field_formatter: :camel_case,
  generate_zod_schemas: false,
  generate_valibot_schemas: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
