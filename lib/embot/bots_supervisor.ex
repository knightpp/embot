defmodule Embot.BotsSupervisor do
  use DynamicSupervisor

  def start_child(req) do
    DynamicSupervisor.start_child(__MODULE__, {Embot.Streamer, req})
  end

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
