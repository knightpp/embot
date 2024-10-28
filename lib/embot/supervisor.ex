defmodule Embot.Supervisor do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok)
  end

  @impl Supervisor
  def init(_) do
    children =
      if Application.fetch_env!(:embot, :env) != :test do
        [
          Embot.BotsSupervisor,
          Embot.Loader
        ]
      else
        [
          Embot.BotsSupervisor
        ]
      end

    Supervisor.init(children, strategy: :one_for_all)
  end
end
