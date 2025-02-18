defmodule Embot do
  alias Embot.Mastodon

  def process_post_by_id(id) do
    access_token = Application.fetch_env!(:embot, :access_token)
    endpoint = Application.fetch_env!(:embot, :endpoint)
    mastodon = Embot.Mastodon.new(endpoint, access_token)

    {:ok, status} = Mastodon.get_status(mastodon.auth, id)

    Embot.Streamer.WebsocketProducer.sync_notify(
      {:mention,
       %{
         "id" => "manual",
         "type" => "mention",
         "account" => status["account"],
         "status" => status
       }}
    )
  end
end
