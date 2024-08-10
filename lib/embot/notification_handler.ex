defmodule Embot.NotificationHandler do
  alias Embot.NotificationHandler.Worker

  defstruct none: nil

  def child_spec(req) do
    Poolex.child_spec(
      pool_id: __MODULE__,
      worker_module: Worker,
      workers_count: 3,
      worker_args: [req]
    )
  end

  def handle_data(data) do
    Poolex.run(__MODULE__, fn pid ->
      Worker.process(pid, data)
    end)
  end
end

defimpl Collectable, for: Embot.NotificationHandler do
  def into(_) do
    callback = fn
      _, {:cont, data} ->
        Embot.NotificationHandler.handle_data(data)
        :ok

      _, :done ->
        {:error, :done}

      _, :halt ->
        {:error, :halt}
    end

    {nil, callback}
  end
end

defmodule Embot.NotificationHandler.Worker do
  use GenServer

  alias Embot.Mastodon
  require Logger

  def start_link(req) do
    GenServer.start_link(__MODULE__, req)
  end

  def process(server, data) do
    GenServer.call(server, {:process, data})
  end

  @impl GenServer
  def init(req) do
    {:ok, req}
  end

  @impl GenServer
  def handle_call({:process, data}, _, req) do
    Embot.Streaming.Sse.parse(data)
    |> dbg()
    |> Stream.filter(fn {key, _} -> key == :data end)
    |> Stream.map(fn {_, data} -> Jason.decode!(data) end)
    |> Enum.each(fn data ->
      status_id = data |> Map.fetch!("status") |> Map.fetch!("id")
      visibility = data |> Map.fetch!("status") |> Map.fetch!("visibility")
      notification_id = Map.fetch!(data, "id")
      account = data |> Map.fetch!("account") |> Map.fetch!("acct")

      Logger.info("replying to #{status_id}")

      Mastodon.post_status!(
        req,
        status: "@#{account} hello!",
        in_reply_to_id: status_id,
        visibility: visibility
      )

      Logger.info("dismissing notification id=#{notification_id}")
      :ok = Mastodon.notification_dismiss!(req, notification_id)
      :timer.sleep(1000)
    end)

    {:reply, :ok, req}
  end
end
