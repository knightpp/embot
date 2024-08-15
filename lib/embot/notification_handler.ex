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
    links = content |> Floki.attribute("a[href*='x.com/i/status']", "href") |> Enum.take(1)

    case links do
      [] ->
        Logger.info("no links in #{status_id}")

      [link] ->
        fxlink = %URI{URI.parse(link) | host: "fixupx.com"} |> URI.to_string()
        twi = get_fxtwitter_ogp!(fxlink)

        media_id = upload_media!(req, twi)
        # wait until media is processed
        Mastodon.get_media!(req, media_id)

        Mastodon.post_status!(req,
          status: "@#{acct}\nOriginally posted #{twi.url}\n\n#{twi.title}\n\n#{twi.description}",
          in_reply_to_id: status_id,
          visibility: "unlisted",
          "media_ids[]": media_id
        )
    end
  end

  defp upload_media!(req, %{video: video, image: image}) when video != nil and image != nil do
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

  defp get_fxtwitter_ogp!(url) do
    %{status: 200, body: body} = Req.get!(url: url, redirect: false, user_agent: "curl")

    document = body |> Floki.parse_document!()

    original_url =
      document |> Floki.attribute("meta[property='og:url'][content]", "content") |> first!()

    description =
      document
      |> Floki.attribute("meta[property='og:description'][content]", "content")
      |> first!()

    title =
      document
      |> Floki.attribute("meta[property='og:title'][content]", "content")
      |> first!()

    image =
      document
      |> Floki.attribute("meta[property='og:image'][content]", "content")
      |> first()

    video =
      document |> Floki.attribute("meta[property='og:video'][content]", "content") |> first()

    %{video: video, description: description, url: original_url, title: title, image: image}
  end

  defp first([]), do: nil
  defp first([a | _]), do: a

  defp first!([a | _]), do: a
end
