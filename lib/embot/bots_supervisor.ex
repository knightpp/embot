defmodule Embot.BotsSupervisor do
  use DynamicSupervisor

  @spec start_child(%Embot.Mastodon{}) :: DynamicSupervisor.on_start_child()
  def start_child(mastodon) do
    DynamicSupervisor.start_child(__MODULE__, {Embot.Streamer, mastodon})
  end

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
