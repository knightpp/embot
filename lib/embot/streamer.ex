defmodule Embot.Streamer do
  use Task, restart: :permanent

  def start_link(req) do
    Task.start_link(__MODULE__, :stream, [req])
  end

  def stream(req) do
    Embot.Mastodon.stream_notifications!(req, %Embot.NotificationHandler{})
  end
end
