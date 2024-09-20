defmodule Embot.Streamer.PanicStorage do
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  @spec push(GenServer.t(), term()) :: integer()
  def push(server, event) do
    GenServer.call(server, {:push, event})
  end

  @spec remove(GenServer.t(), integer()) :: :ok
  def remove(server, id) do
    GenServer.call(server, {:remove, id})
  end

  @impl GenServer
  def init(_arg) do
    Process.flag(:trap_exit, true)
    {:ok, {0, %{}}}
  end

  @impl GenServer
  def handle_call({:push, event}, _from, {n, events}) do
    events = Map.put(events, n, event)
    {:reply, n, {n + 1, events}}
  end

  @impl GenServer
  def handle_call({:remove, id}, _from, {n, events}) do
    {:reply, :ok, {n, Map.delete(events, id)}}
  end

  @impl GenServer
  def terminate(reason, {n, events}) do
    if Enum.count(events) > 0 do
      Embot.Streamer.Producer.sync_notify(Map.values(events))
    end

    {:stop, reason, {n, events}}
  end
end
