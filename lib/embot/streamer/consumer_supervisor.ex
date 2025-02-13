defmodule Embot.Streamer.ConsumerSupervisor do
  # TODO: Use GenStage.Supervisor?
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @impl Supervisor
  def init(args) do
    children = [
      consumer_spec(args, :consumer1),
      consumer_spec(args, :consumer2),
      consumer_spec(args, :consumer3),
      consumer_spec(args, :consumer4),
      consumer_spec(args, :consumer5)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp consumer_spec(args, id) do
    Supervisor.child_spec({Embot.Streamer.Consumer, args}, id: id)
  end
end
