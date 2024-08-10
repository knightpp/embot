defmodule Embot.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    access_token = Application.fetch_env!(:embot, :access_token)
    req = Embot.Mastodon.new("https://mastodon.knightpp.cc", access_token)

    children = [
      {Embot.NotificationHandler, req},
      {Embot.Streamer, req}
    ]

    opts = [strategy: :one_for_one, name: Embot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
