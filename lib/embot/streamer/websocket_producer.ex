defmodule Embot.Streamer.WebsocketProducer do
  use GenStage

  def start_link(mastodon) do
    GenStage.start_link(__MODULE__, mastodon, name: __MODULE__)
  end

  @impl GenStage
  def init(mastodon) do
    {:producer, mastodon}
  end
end
