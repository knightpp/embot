defmodule Embot.Backlog do
  use Task
  require Logger
  alias Embot.Mastodon

  def start_link(mastodon) do
    Task.start_link(__MODULE__, :run, [mastodon])
  end

  def run(mastodon, sender \\ &Embot.Streamer.Producer.sync_notify/1) do
    mentions = Mastodon.notifications!(mastodon.auth, types: :mention)
    Logger.notice("found unread mentions", unread: length(mentions))

    mentions |> Enum.each(&sender.({:mention, &1}))
  end
end
