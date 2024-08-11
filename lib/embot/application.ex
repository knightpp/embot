defmodule Embot.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    access_token = Application.fetch_env!(:embot, :access_token)
    endpoint = Application.fetch_env!(:embot, :endpoint)
    req = Embot.Mastodon.new(endpoint, access_token)

    children = [
      {Embot.Streamer, req},
      {Embot.Backlog, req}
    ]

    opts = [strategy: :one_for_one, name: Embot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
