defmodule Embot.NotificationHandler do
  require Logger
  alias Embot.Mastodon

  def process_mention(event, req) do
    Logger.info("received event #{event["id"]} at #{event["created_at"]}")

    with :ok <- parse_link_and_send_reply!(req, event) do
      notification_id = event |> Map.fetch!("id")
      Logger.notice("dismissing notification id=#{notification_id}")

      with {:ok, %{status: status}} <- Mastodon.notification_dismiss(req, notification_id) do
        case status do
          200 -> :ok
          404 -> :ok
        end
      end
    end
  end

  defp parse_link_and_send_reply!(_req, %{"account" => %{"bot" => true, "acct" => acct}}) do
    Logger.warning("got a message from bot! @#{acct}")
    :ok
  end

  defp parse_link_and_send_reply!(
         req,
         %{
           "account" => %{"acct" => acct},
           "type" => "mention",
           "status" => %{
             "id" => status_id,
             "content" => content,
             "visibility" => visibility,
             "edited_at" => nil
           }
         }
       ) do
    content = content |> Floki.parse_document!()

    args = Embot.Command.parse(Floki.text(content))

    links =
      Floki.attribute(content, "a[href^='https://x.com']", "href") ++
        Floki.attribute(content, "a[href^='https://twitter.com']", "href")

    if links == [] do
      Logger.info("no links in #{status_id}")
      :ok
    else
      visibility =
        case visibility do
          "direct" -> "direct"
          _ -> "unlisted"
        end

      links_stream =
        links
        |> Enum.sort()
        |> Stream.dedup()
        |> Stream.take(10)

      results =
        Task.Supervisor.async_stream_nolink(
          Embot.HandlerTaskSupervisor,
          links_stream,
          fn link ->
            twi = Embot.Fxtwi.get!(req, link)

            media_id = upload_media!(req, twi)
            wait_media_processing!(req, media_id)

            status =
              "@#{acct}\nOriginally posted #{twi.url}\n\n#{twi.title}\n\n#{twi.description}"
              |> limit_string(500)

            Mastodon.post_status!(
              req,
              Keyword.merge(
                [
                  status: status,
                  in_reply_to_id: status_id,
                  visibility: visibility,
                  "media_ids[]": media_id
                ],
                args_to_request(args)
              )
            )
          end,
          ordered: false,
          timeout: :timer.minutes(2)
        )
        |> Stream.filter(&match?({:exit, _}, &1))
        |> Stream.map(fn {:exit, reason} -> reason end)
        |> Enum.to_list()

      case results do
        [] -> :ok
        errors -> {:error, errors}
      end
    end
  end

  defp parse_link_and_send_reply!(_req, %{
         "type" => "mention",
         "status" => %{"edited_at" => _notnil}
       }) do
    Logger.notice("discarded edit of previous status")
    :ok
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
        "mention" -> :ok
        _ -> :unknown
      end

    if type != :ok do
      Logger.warning("notification type=#{notification["type"]} is unknown")
    else
      Logger.info("not handling notification=#{notification["id"]} type=#{notification["type"]}")
    end

    :ok
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

  defp args_to_request(args) do
    Enum.reduce(args, [], fn
      {:cw, nil}, acc -> Keyword.put(acc, :sensitive, "true")
      {:cw, spoiler_text}, acc -> [{:sensitive, "true"}, {:spoiler_text, spoiler_text} | acc]
    end)
  end
end
