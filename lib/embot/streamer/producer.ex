defmodule Embot.Streamer.Producer do
  require Logger
  use GenStage
  alias Embot.KeepAlive

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
    case KeepAlive.start_link(:ok) do
      {:ok, pid} ->
        %{status: 200} = Embot.Mastodon.stream_notifications!(req, :self)
        {:producer, {pid, []}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenStage
  def handle_demand(_demand, state) do
    # Ignore demand, see https://hexdocs.pm/gen_stage/GenStage.html#module-buffering-demand

    # {return, rest} = Enum.split(queue, demand)
    {:noreply, [], state}
  end

  @impl GenStage
  def handle_info({_, {:data, ":thump\n"}}, {pid, acc}) do
    KeepAlive.keep_alive(pid)
    Logger.debug("thump")
    {:noreply, [], {pid, acc}}
  end

  @impl GenStage
  def handle_info({_, {:data, chunk}}, {pid, acc}) do
    KeepAlive.keep_alive(pid)
    # this is always sequential
    {ready, acc} = Embot.Sse.accumulate(acc, chunk)

    Logger.info(
      "accumulate sse chunk: ready_size=#{Enum.count(ready)}, acc_size=#{Enum.count(acc)}"
    )

    {:noreply, ready, {pid, acc}}
  end

  if Application.compile_env!(:embot, :env) == :test do
    @impl GenStage
    def handle_info({{Finch.HTTP1.Pool, _}, :done}, acc) do
      {:noreply, [], acc}
    end
  end

  @impl GenStage
  def handle_info({_, {:error, %Mint.TransportError{reason: :closed}}}, state) do
    {:stop, :shutdown, state}
  end

  @impl GenStage
  def handle_info({_, {:error, %Mint.TransportError{reason: :done}}}, state) do
    {:stop, :shutdown, state}
  end

  @impl GenStage
  def handle_call({:notify, payload}, _from, state) do
    events = if is_list(payload), do: payload, else: [payload]
    {:reply, :ok, events, state}
  end
end
