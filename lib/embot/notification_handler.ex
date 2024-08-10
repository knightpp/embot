defmodule Embot.NotificationHandler do
  require Logger
  alias Embot.NotificationHandler.Worker

  defstruct callback: nil

  def new() do
    # TODO: Use callback?
    %__MODULE__{callback: nil}
  end

  def child_spec(req) do
    Poolex.child_spec(
      pool_id: __MODULE__,
      worker_module: Worker,
      workers_count: 3,
      worker_args: [req]
    )
  end

  def handle_sse(sse_data) do
    Embot.Sse.parse!(sse_data)
    |> Stream.filter(fn {key, _} -> key == :data end)
    |> Enum.each(fn {_, data} -> handle_mention(data) end)
  end

  def handle_mention(data) do
    Logger.info("handle mention #{data["id"]}")

    Poolex.run(__MODULE__, fn pid ->
      Worker.process(pid, data)
    end)
  end
end

defimpl Collectable, for: Embot.NotificationHandler do
  def into(_) do
    callback = fn
      _, {:cont, data} ->
        Embot.NotificationHandler.handle_sse(data)
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

    {:reply, :ok, req}
  end
end
