defmodule Embot.Loader do
  use Task, restart: :transient

  def start_link(_) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    access_token = Application.fetch_env!(:embot, :access_token)
    endpoint = Application.fetch_env!(:embot, :endpoint)
    req = Embot.Mastodon.new(endpoint, access_token)

    {:ok, _pid} = Embot.BotsSupervisor.start_child(req)
  end
end
