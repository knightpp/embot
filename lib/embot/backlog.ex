defmodule Embot.Backlog do
  use Task
  require Logger
  alias Embot.Mastodon

  @spec start_link(Embot.Mastodon.t()) :: {:ok, pid()}
  def start_link(mastodon) do
    Task.start_link(__MODULE__, :run, [mastodon])
  end

  @spec run(Embot.Mastodon.t(), fun(term())) :: :ok
  def run(mastodon, sender \\ &Embot.Streamer.WebsocketProducer.sync_notify/1) do
    mentions = Mastodon.notifications!(mastodon.auth, types: :mention)
    Logger.notice("checking unread mentions", unread: length(mentions))

    mentions |> Enum.each(&sender.({:mention, &1}))
    :ok
  end
end
