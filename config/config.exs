import Config

log_level =
  if config_env() == :prod do
    :info
  else
    :debug
  end

config :logger, level: log_level

config :logger, :default_formatter,
  format: "lvl=$level msg=\"$message\" $metadata\n",
  metadata: :all

config :embot,
  env: config_env(),
  fs_video: System.get_env("ENABLE_FS_VIDEO", "0") != "0",
  status_char_limit: 500,
  media_attachment_limit: 4
