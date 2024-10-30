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
    send(self(), {:late_init, req})

    {:producer, :uninitialized}
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

    {:noreply, ready, {pid, acc}}
  end

  if Application.compile_env!(:embot, :env) == :test do
    @impl GenStage
    def handle_info({{Finch.HTTP1.Pool, _}, :done}, acc) do
      {:noreply, [], acc}
    end
  else
    @impl GenStage
    def handle_info({{Finch.HTTP1.Pool, _}, :done}, state) do
      {:stop, {:shutdown, :pool_done}, state}
    end
  end

  @impl GenStage
  def handle_info({_, {:error, %Mint.TransportError{reason: :closed}}}, state) do
    {:stop, {:shutdown, :transport_closed}, state}
  end

  @impl GenStage
  def handle_info({_, {:error, %Mint.TransportError{reason: :done}}}, state) do
    {:stop, {:shutdown, :transport_done}, state}
  end

  @impl GenStage
  def handle_info({_, {:error, %Mint.TransportError{reason: :timeout}}}, state) do
    {:stop, {:shutdown, :transport_timeout}, state}
  end

  @impl true
  def handle_info({:late_init, req}, _state) do
    {:ok, pid} = KeepAlive.start_link(:ok)
    # this will retry any error up to 100 times using default exponential backoff
    %{status: 200} =
      Embot.Mastodon.stream_notifications!(req, :self,
        retry: fn _, resp_or_exception -> transient?(resp_or_exception) end,
        max_retries: 100
      )

    {:noreply, [], {pid, []}}
  end

  @impl GenStage
  def handle_call({:notify, payload}, _from, state) do
    events = if is_list(payload), do: payload, else: [payload]
    {:reply, :ok, events, state}
  end

  defp transient?(%Req.Response{status: status})
       when status in [408, 429, 500, 502, 503, 504, 530] do
    true
  end

  defp transient?(%Req.Response{}) do
    false
  end

  defp transient?(%Req.TransportError{reason: reason})
       when reason in [:timeout, :econnrefused, :closed] do
    true
  end

  defp transient?(%Req.HTTPError{protocol: :http2, reason: :unprocessed}) do
    true
  end

  defp transient?(%{__exception__: true}) do
    false
  end
end
