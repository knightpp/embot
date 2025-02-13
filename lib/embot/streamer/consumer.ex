defmodule Embot.Streamer.Consumer do
  use GenStage
  require Logger

  def start_link(mastodon, producer \\ Embot.Streamer.SSEProducer) do
    GenStage.start_link(__MODULE__, {mastodon, producer})
  end

  @impl GenStage
  def init({mastodon, producer}) do
    {:consumer, mastodon, subscribe_to: [{producer, max_demand: 1}]}
  end

  @impl GenStage
  def handle_events(events, _from, mastodon) do
    Enum.each(events, fn event ->
      case event do
        {:mention, mention} ->
          Embot.NotificationHandler.process_mention(mention, mastodon.auth) |> maybe_log_error()

        chunk ->
          parse_sse(chunk)
          |> Enum.map(&Embot.NotificationHandler.process_mention(&1, mastodon))
          |> Enum.each(&maybe_log_error/1)
      end
    end)

    {:noreply, [], mastodon}
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
        Logger.info("stopping consumer", reason: reason)

      reason ->
        Logger.warning("stopping consumer", reason: reason)
    end

    {:noreply, [], state}
  end

  defp parse_sse(sse_data) do
    Embot.Sse.parse(sse_data)
    |> Stream.filter(fn
      {:ok, {key, _}} ->
        key == :data

      {:error, error} ->
        Logger.error("could not parse sse line", error: error)
        false
    end)
    |> Stream.map(fn {:ok, {_, data}} -> data end)
  end
end

defmodule Embot.Streamer.ConsumerSupervisor do
  # TODO: Use GenStage.Supervisor?
  use Supervisor

  def start_link(mastodon) do
    Supervisor.start_link(__MODULE__, mastodon)
  end

  @impl Supervisor
  def init(mastodon) do
    children = [
      consumer_spec(mastodon, :consumer1),
      consumer_spec(mastodon, :consumer2),
      consumer_spec(mastodon, :consumer3),
      consumer_spec(mastodon, :consumer4),
      consumer_spec(mastodon, :consumer5)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp consumer_spec(mastodon, id) do
    Supervisor.child_spec({Embot.Streamer.Consumer, mastodon}, id: id)
  end
end
