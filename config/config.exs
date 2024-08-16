import Config

log_level =
  if config_env() == :prod do
    :warning
  else
    :debug
  end

config :floki, :html_parser, Floki.HTMLParser.Html5ever
config :logger, level: log_level
