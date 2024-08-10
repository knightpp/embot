defmodule Embot.Backlog do
  use Task
  require Logger
  alias Embot.Mastodon

  def start_link(req) do
    Task.start_link(__MODULE__, :run, [req])
  end

  def run(req) do
    mentions = Mastodon.notifications!(req, types: :mention)
    Logger.info("found #{length(mentions)} unread mentions")

    mentions
    |> Task.async_stream(
      fn mention ->
        Embot.NotificationHandler.handle_mention(mention)
      end,
      ordered: false
    )
    |> Stream.run()
  end
end
