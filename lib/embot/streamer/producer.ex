defmodule Embot.Streamer.Producer do
  use GenStage

  def start_link(req) do
    GenStage.start_link(__MODULE__, req, name: __MODULE__)
  end

  @doc "Used to put events OOB, like when reading backlog."
  def sync_notify(event, timeout \\ 5000) do
    GenStage.call(__MODULE__, {:notify, event}, timeout)
  end

  @impl GenStage
  def init(req) do
    %{status: 200} = Embot.Mastodon.stream_notifications!(req, :self)

    {:producer, []}
  end

  @impl GenStage
  def handle_demand(_demand, queue) do
    # Ignore demand, see https://hexdocs.pm/gen_stage/GenStage.html#module-buffering-demand

    # {return, rest} = Enum.split(queue, demand)
    {:noreply, [], queue}
  end

  @doc """
    Handles SSE chunk callback.
  """
  @impl GenStage
  def handle_info({_, {:data, chunk}}, queue) do
    {:noreply, [{:chunk, chunk}], queue}
  end

  @impl GenStage
  def handle_call({:notify, event}, _from, queue) do
    {:reply, :ok, [event], queue}
  end
end
