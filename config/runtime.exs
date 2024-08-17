import Config

dotenv = Embot.Dotenv.read(".env")

fetch_env = fn key ->
  System.get_env(key) || dotenv[key] || raise "no configuration provided for #{key}"
end

with {:ok, var} <- System.fetch_env("LOG_LEVEL") do
  level =
    case var do
      "error" -> :error
      "warning" -> :warning
      "notice" -> :notice
      "info" -> :info
      "debug" -> :debug
    end

  config :logger, level: level
end

config :embot,
  access_token: fetch_env.("BOT_ACCESS_TOKEN"),
  endpoint: fetch_env.("BOT_ENDPOINT")
