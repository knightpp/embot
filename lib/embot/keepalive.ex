defmodule Embot.KeepAlive do
  use GenServer

  @timeout :timer.minutes(5)

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def keep_alive(server, timeout \\ 5000) do
    GenServer.call(server, :keep_alive, timeout)
  end

  @impl GenServer
  def init(_arg) do
    {:ok, nil, @timeout}
  end

  @impl GenServer
  def handle_call(:keep_alive, _from, nil) do
    {:reply, :ok, nil, @timeout}
  end

  @impl true
  def handle_info(:timeout, nil) do
    {:stop, :timeout, nil}
  end
end
