import Config

log_level =
  if config_env() == :prod do
    :info
  else
    :debug
  end

config :floki, :html_parser, Floki.HTMLParser.FastHtml
config :logger, level: log_level
config :embot, env: config_env()
