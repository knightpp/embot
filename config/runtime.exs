import Config

dotenv = Embot.Dotenv.read(".env")

fetch_env = fn key ->
  System.get_env(key) || dotenv[key] || raise "no configuration provided for #{key}"
end

config :embot,
  client_id: fetch_env.("BOT_CLIENT_ID"),
  client_secret: fetch_env.("BOT_CLIENT_SECRET"),
  access_token: fetch_env.("BOT_ACCESS_TOKEN")
