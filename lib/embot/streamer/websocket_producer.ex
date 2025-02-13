defmodule Embot.Streamer.WebsocketProducer do
  use GenStage

  def start_link(mastodon) do
    GenStage.start_link(__MODULE__, mastodon, name: __MODULE__)
  end

  @spec sync_notify(term() | list(), pos_integer()) :: :ok
  def sync_notify(event, timeout \\ 5000) do
    GenStage.call(__MODULE__, {:notify, event}, timeout)
  end

  @impl GenStage
  def init(mastodon) do
    {:producer, mastodon}
  end

  @impl GenStage
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  @impl GenStage
  def handle_call({:notify, payload}, _from, state) do
    events = if is_list(payload), do: payload, else: [payload]
    {:reply, :ok, events, state}
  end
end
