defmodule Embot.Streamer.Producer do
  require Logger
  use GenStage

  def start_link(req) do
    GenStage.start_link(__MODULE__, req, name: __MODULE__)
  end

  @doc "Used to put events OOB, like when reading backlog."
  @spec sync_notify(term() | list(), pos_integer()) :: :ok
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

  @impl GenStage
  def handle_info({_, {:data, ":thump\n"}}, acc) do
    Logger.debug("thump")
    {:noreply, [], acc}
  end

  @impl GenStage
  def handle_info({_, {:data, chunk}}, acc) do
    Logger.debug("accumulate sse chunk")

    # this is always sequential
    case Embot.Sse.accumulate(acc, chunk) do
      {:more, acc} ->
        {:noreply, [], acc}

      {:done, result} ->
        {:noreply, [{:chunk, result}], []}
    end
  end

  @impl GenStage
  def handle_call({:notify, event}, _from, queue) do
    {:reply, :ok, [event], queue}
  end
end
