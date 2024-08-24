defmodule Embot.Backlog do
  use Task
  require Logger
  alias Embot.Mastodon

  def start_link(req) do
    Task.start_link(__MODULE__, :run, [req])
  end

  def run(req, sender \\ &Embot.Streamer.Producer.sync_notify/1) do
    mentions = Mastodon.notifications!(req, types: :mention)
    Logger.notice("found #{length(mentions)} unread mentions")

    mentions |> Enum.each(&sender.({:mention, &1}))
  end
end
