import Config

config :floki, :html_parser, Floki.HTMLParser.Html5ever
config :logger, :default_formatter, metadata: [:error]
