defmodule Embot do
  require Logger
  alias Embot.Mastodon

  def test() do
    access_token = Application.fetch_env!(:embot, :access_token)
    req = Mastodon.new("https://mastodon.knightpp.cc", access_token)

    # Mastodon.verify_credentials!(req)
    Mastodon.stream_notifications!(req, make_process_stream(req))
  end

  def make_process_stream(orig_req) do
    fn {:data, data}, {req, resp} ->
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
          orig_req,
          status: "@#{account} hello!",
          in_reply_to_id: status_id,
          visibility: visibility
        )

        Logger.info("dismissing notification id=#{notification_id}")
        :ok = Mastodon.notification_dismiss!(orig_req, notification_id)
        :timer.sleep(1000)
      end)

      {:cont, {req, resp}}
    end
  end
end
