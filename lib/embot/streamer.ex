defmodule Embot.Streamer do
  use Supervisor

  def start_link(mastodon, producer \\ Embot.Streamer.SSEProducer) do
    Supervisor.start_link(__MODULE__, {mastodon, producer})
  end

  @impl Supervisor
  def init({mastodon, producer}) do
    children = [
      {producer, mastodon},
      {Embot.Streamer.ConsumerSupervisor, mastodon},
      {Embot.Backlog, mastodon}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
