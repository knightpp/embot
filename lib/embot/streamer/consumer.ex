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
          :ok = Embot.NotificationHandler.process_mention(mention, req)

        chunk ->
          parse_sse(chunk)
          |> Enum.map(&Embot.NotificationHandler.process_mention(&1, req))
      end
    end)

    {:noreply, [], req}
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
