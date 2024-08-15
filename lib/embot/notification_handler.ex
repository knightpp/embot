defmodule Embot.NotificationHandler do
  require Logger
  alias Embot.Mastodon

  def handle_sse(sse_data, req) do
    Embot.Sse.parse!(sse_data)
    |> Stream.filter(fn {key, _} -> key == :data end)
    |> Enum.each(fn {_, data} -> process_mention(data, req) end)
  end

  def process_mention(data, req) do
    parse_link_and_send_reply!(req, data)

    notification_id = data |> Map.fetch!("id")
    Logger.info("dismissing notification id=#{notification_id}")
    :ok = Mastodon.notification_dismiss!(req, notification_id)
    {:noreply, req}
  end

  defp parse_link_and_send_reply!(_req, %{"account" => %{"bot" => true, "acct" => acct}}) do
    Logger.warning("got a message from bot! @#{acct}")
  end

  defp parse_link_and_send_reply!(
         req,
         %{
           "account" => %{"acct" => acct},
           "status" => %{"id" => status_id, "content" => content}
         }
       ) do
    content = content |> Floki.parse_document!()

    links =
      Floki.attribute(content, "a[href^='https://x.com']", "href") ++
        Floki.attribute(content, "a[href^='https://twitter.com']", "href")

    case Enum.take(links, 1) do
      [] ->
        Logger.info("no links in #{status_id}")

      [link] ->
        twi = Embot.Fxtwi.get!(link)

        media_id = upload_media!(req, twi)
        wait_media_processing!(req, media_id)

        Mastodon.post_status!(req,
          status: "@#{acct}\nOriginally posted #{twi.url}\n\n#{twi.title}\n\n#{twi.description}",
          in_reply_to_id: status_id,
          visibility: "unlisted",
          "media_ids[]": media_id
        )
    end
  end

  defp wait_media_processing!(_req, nil), do: :no_media

  defp wait_media_processing!(req, media_id) do
    case Mastodon.get_media!(req, media_id) do
      {:processing, _} ->
        :timer.sleep(:timer.seconds(1))
        wait_media_processing!(req, media_id)

      {:ok, _} ->
        :ok
    end
  end

  defp upload_media!(_req, %{video: nil, image: nil}), do: nil

  defp upload_media!(req, %{video: nil, image: image_url}) do
    %{status: 200, body: image, headers: %{"content-type" => [image_mime]}} =
      Req.get!(url: image_url, redirect: false)

    %{"id" => id} =
      Mastodon.upload_media!(req, file: {image, content_type: image_mime, filename: image_url})

    id
  end

  # When there's video, the image is a thumbnail
  defp upload_media!(req, %{video: video, image: image}) do
    %{status: 200, body: thumbnail, headers: %{"content-type" => [image_mime]}} =
      Req.get!(url: image, redirect: false)

    # did not work with into: :self
    %{status: 200, body: video_binary, headers: %{"content-type" => [video_mime]}} =
      Req.get!(url: video, redirect: false)

    %{"id" => id} =
      Mastodon.upload_media!(req,
        file: {video_binary, content_type: video_mime, filename: video},
        thumbnail: {thumbnail, content_type: image_mime, filename: image}
      )

    id
  end
end
