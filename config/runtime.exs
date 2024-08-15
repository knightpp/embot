import Config

dotenv = Embot.Dotenv.read(".env")

fetch_env = fn key ->
  System.get_env(key) || dotenv[key] || raise "no configuration provided for #{key}"
end

config :embot,
  access_token: fetch_env.("BOT_ACCESS_TOKEN"),
  endpoint: fetch_env.("BOT_ENDPOINT")
