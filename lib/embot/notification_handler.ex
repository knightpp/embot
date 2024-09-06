defmodule Embot.NotificationHandler do
  require Logger
  alias Embot.Mastodon

  def handle_sse(sse_data, req) do
    Embot.Sse.parse(sse_data)
    |> Stream.filter(fn
      {:ok, {key, _}} ->
        key == :data

      {:error, error} ->
        Logger.error("could not parse sse line", error: inspect(error))
        false
    end)
    |> Enum.each(fn {:ok, {_, data}} -> process_mention(data, req) end)
  end

  def process_mention(data, req) do
    parse_link_and_send_reply!(req, data)

    notification_id = data |> Map.fetch!("id")
    Logger.notice("dismissing notification id=#{notification_id}")
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
           "type" => "mention",
           "status" => %{"id" => status_id, "content" => content, "visibility" => visibility}
         }
       ) do
    content = content |> Floki.parse_document!()

    links =
      Floki.attribute(content, "a[href^='https://x.com']", "href") ++
        Floki.attribute(content, "a[href^='https://twitter.com']", "href")

    if links == [] do
      Logger.info("no links in #{status_id}")
    else
      visibility =
        case visibility do
          "direct" -> "direct"
          _ -> "unlisted"
        end

      Enum.each(links, fn link ->
        twi = Embot.Fxtwi.get!(link)

        media_id = upload_media!(req, twi)
        wait_media_processing!(req, media_id)

        status =
          "@#{acct}\nOriginally posted #{twi.url}\n\n#{twi.title}\n\n#{twi.description}"
          |> limit_string(500)

        Mastodon.post_status!(req,
          status: status,
          in_reply_to_id: status_id,
          visibility: visibility,
          "media_ids[]": media_id
        )
      end)
    end
  end

  defp parse_link_and_send_reply!(_req, notification) do
    type =
      case notification["type"] do
        "status" -> :ok
        "reblog" -> :ok
        "follow" -> :ok
        "follow_request" -> :ok
        "favourite" -> :ok
        "poll" -> :ok
        "update" -> :ok
        "admin.sign_up" -> :ok
        "admin.report" -> :ok
        "severed_relationships" -> :ok
        "moderation_warning" -> :ok
        _ -> :unknown
      end

    if type != :ok do
      Logger.warning("got unknown notification")
      dbg(notification)
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

  defp upload_media!(req, %{video: nil, image: url}) do
    %{status: 200, body: image, headers: %{"content-type" => [mime]}} =
      Req.get!(url: url, redirect: false)

    %{"id" => id} = Mastodon.upload_media!(req, file: {image, content_type: mime, filename: url})

    id
  end

  defp upload_media!(req, %{video: video, video_mime: video_mime}) do
    %{status: 200, body: video_binary, headers: video_headers} =
      Req.get!(url: video, redirect: false)

    content_type = video_mime || getContentType(video_headers, "video/mp4")
    file = {video_binary, content_type: content_type, filename: video}

    %{"id" => id} = Mastodon.upload_media!(req, file: file)

    id
  end

  defp getContentType(headers, default) do
    case headers["content-type"] do
      [ct | _] -> ct
      _ -> default
    end
  end

  defp limit_string(str, max) when max > 1 do
    if String.length(str) <= max do
      str
    else
      str |> String.slice(0, max - 1) |> Kernel.<>("…")
    end
  end
end
