defmodule Embot.Streamer.Consumer do
  use GenStage
  require Logger

  def start_link(req) do
    GenStage.start_link(__MODULE__, req)
  end

  @impl GenStage
  def init(req) do
    {:consumer, req, subscribe_to: [{Embot.Streamer.Producer, max_demand: 1}]}
  end

  @impl GenStage
  def handle_events(events, _from, req) do
    Enum.each(events, fn event ->
      case event do
        {:mention, mention} ->
          Embot.NotificationHandler.process_mention(mention, req) |> maybe_log_error()

        chunk ->
          parse_sse(chunk)
          |> Enum.map(&Embot.NotificationHandler.process_mention(&1, req))
          |> Enum.each(&maybe_log_error/1)
      end
    end)

    {:noreply, [], req}
  end

  defp maybe_log_error(result) do
    case result do
      :ok -> :ok
      {:error, reason} -> Logger.error(reason)
    end
  end

  # This replaces default log like this:
  # [notice] GenStage consumer #PID<0.1223.0> is stopping after receiving cancel from producer #PID<0.1214.0> with reason: ...
  @impl GenStage
  def handle_cancel({:down, {:shutdown, reason}}, _from, state) do
    case reason do
      reason
      when reason in [:transport_closed, :transport_done, :transport_timeout, :pool_done] ->
        Logger.info("stopping consumer because reason=#{inspect(reason)}")

      reason ->
        Logger.warning("stopping consumer because reason=#{inspect(reason)}")
    end

    {:noreply, [], state}
  end

  defp parse_sse(sse_data) do
    Embot.Sse.parse(sse_data)
    |> Stream.filter(fn
      {:ok, {key, _}} ->
        key == :data

      {:error, error} ->
        Logger.error("could not parse sse line", error: inspect(error))
        false
    end)
    |> Stream.map(fn {:ok, {_, data}} -> data end)
  end
end

defmodule Embot.Streamer.ConsumerSupervisor do
  # TODO: Use GenStage.Supervisor?
  use Supervisor

  def start_link(req) do
    Supervisor.start_link(__MODULE__, req)
  end

  @impl Supervisor
  def init(req) do
    children = [
      consumer_spec(req, :consumer1),
      consumer_spec(req, :consumer2),
      consumer_spec(req, :consumer3),
      consumer_spec(req, :consumer4),
      consumer_spec(req, :consumer5)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp consumer_spec(req, id) do
    Supervisor.child_spec({Embot.Streamer.Consumer, req}, id: id)
  end
end
