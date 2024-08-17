defmodule Embot.Backlog do
  use Task
  require Logger
  alias Embot.Mastodon

  def start_link(req) do
    Task.start_link(__MODULE__, :run, [req])
  end

  def run(req) do
    mentions = Mastodon.notifications!(req, types: :mention)
    Logger.notice("found #{length(mentions)} unread mentions")

    mentions |> Enum.each(&Embot.Streamer.Producer.sync_notify({:mention, &1}))
  end
end
