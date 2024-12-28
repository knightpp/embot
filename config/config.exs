import Config

log_level =
  if config_env() == :prod do
    :info
  else
    :debug
  end

config :logger, level: log_level

config :embot,
  env: config_env(),
  fs_video: System.get_env("ENABLE_FS_VIDEO", "0") != "0"
