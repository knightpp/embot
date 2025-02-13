defmodule Embot.Streamer do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @impl Supervisor
  def init(mastodon) do
    use_sse = false

    children =
      if use_sse do
        [
          {Embot.Streamer.SSEProducer, mastodon},
          {Embot.Streamer.ConsumerSupervisor, {mastodon, Embot.Streamer.SSEProducer}},
          {Embot.Backlog, mastodon}
        ]
      else
        # MyWebSocketClient.start_link(uri: "wss://example.com/socket", state: %{}, opts: [
        #   name: {:local, :my_connection}
        # ])
        #
        uri = URI.parse(mastodon.url)
        uri = %{uri | scheme: "wss://", path: "/api/v1/streaming"} | URI.to_string()

        [
          # TODO: authorize and subscribe to correct feed
          {Embot.Streamer.Websocket, uri: uri},
          {Embot.Streamer.ConsumerSupervisor, {mastodon, Embot.Streamer.WebsocketProducer}},
          {Embot.Backlog, mastodon}
        ]
      end

    # MyWebSocketClient.start_link(
    #   uri: "wss://example.com/socket",
    #   state: %{},
    #   opts: [
    #     name: {:local, :my_connection}
    #   ]
    # )

    children =
      Supervisor.init(children, strategy: :rest_for_one)
  end
end
