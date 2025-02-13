defmodule Embot.Streamer do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @impl Supervisor
  def init(mastodon) do
    uri = URI.parse(mastodon.url)

    uri =
      %{
        uri
        | scheme: "wss",
          path: "/api/v1/streaming/",
          query: "stream=user:notification"
      }
      |> URI.to_string()

    websocket_args = [
      uri: uri,
      state: %{},
      opts: [
        headers: [{"Authorization", "Bearer #{mastodon.token}"}],
        hibernate_after: :timer.minutes(2)
      ]
    ]

    children = [
      {Embot.Streamer.Websocket, websocket_args},
      {Embot.Streamer.WebsocketProducer, mastodon},
      {Embot.Streamer.ConsumerSupervisor, {mastodon, Embot.Streamer.WebsocketProducer}},
      {Embot.Backlog, mastodon}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
