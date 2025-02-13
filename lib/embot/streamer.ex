defmodule Embot.Streamer do
  use Supervisor

  def start_link(mastodon) do
    Supervisor.start_link(__MODULE__, mastodon)
  end

  @impl Supervisor
  def init(mastodon) do
    children = [
      {Embot.Streamer.Producer, mastodon},
      {Embot.Streamer.ConsumerSupervisor, mastodon},
      {Embot.Backlog, mastodon}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
