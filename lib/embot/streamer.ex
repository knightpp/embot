defmodule Embot.Streamer do
  use Supervisor

  def start_link(req) do
    Supervisor.start_link(__MODULE__, req)
  end

  @impl Supervisor
  def init(req) do
    children = [
      {Embot.Streamer.Producer, req},
      {Embot.Streamer.ConsumerSupervisor, req},
      {Embot.Backlog, req}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
