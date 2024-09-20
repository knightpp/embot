defmodule Embot.Streamer.Consumer do
  use GenStage

  alias Embot.Streamer.PanicStorage

  def start_link(req) do
    GenStage.start_link(__MODULE__, req)
  end

  @impl GenStage
  def init(req) do
    case PanicStorage.start_link(nil) do
      {:ok, ps} ->
        {:consumer, {ps, req}, subscribe_to: [{Embot.Streamer.Producer, max_demand: 1}]}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenStage
  def handle_events(events, _from, {ps, req}) do
    events
    |> Enum.each(fn event ->
      tmp_id = PanicStorage.push(ps, event)

      case event do
        {:mention, mention} ->
          :ok = Embot.NotificationHandler.process_mention(mention, req)

        chunk ->
          Embot.NotificationHandler.handle_sse(chunk, req) |> Enum.each(fn :ok -> :ok end)
      end

      PanicStorage.remove(ps, tmp_id)
    end)

    {:noreply, [], req}
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
