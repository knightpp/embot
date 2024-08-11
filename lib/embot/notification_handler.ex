defmodule Embot.NotificationHandler do
  require Logger
  alias Embot.Mastodon

  def handle_sse(sse_data, req) do
    Embot.Sse.parse!(sse_data)
    |> Stream.filter(fn {key, _} -> key == :data end)
    |> Enum.each(fn {_, data} -> process_mention(data, req) end)
  end

  def process_mention(data, req) do
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

    {:noreply, req}
  end
end
