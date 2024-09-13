defmodule Embot.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        Embot.BotsSupervisor,
        {Task.Supervisor, name: Embot.HandlerTaskSupervisor}
      ] ++
        if Application.fetch_env!(:embot, :env) != :test do
          [Embot.Loader]
        else
          []
        end

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end
