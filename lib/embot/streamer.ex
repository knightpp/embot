defmodule Embot.Streamer do
  use Task, restart: :permanent

  def start_link(req) do
    Task.start_link(__MODULE__, :stream, [req])
  end

  def stream(req) do
    handler = Embot.NotificationHandler.new()
    Embot.Mastodon.stream_notifications!(req, handler)
  end
end
