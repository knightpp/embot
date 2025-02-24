defmodule Embot.NotificationHandler do
  require Logger
  alias Embot.Mastodon
  alias Embot.NotificationHandler.LinkContext

  @status_char_limit Application.compile_env!(:embot, :status_char_limit)
  @attachments_limit Application.compile_env!(:embot, :media_attachment_limit)

  @spec process_mention(map(), Embot.Mastodon.t()) :: :ok | {:error, term()}
  def process_mention(event, %Embot.Mastodon{} = mastodon) do
    Logger.info("received event",
      id: event["id"],
      ts: event["created_at"],
      url: get_in(event, ["status", "url"])
    )

    case parse_links_and_send_reply!(mastodon, event) do
      :ok ->
        dismiss_notification(event, mastodon, :ok)

      {:error, :bot = reason} ->
        dismiss_notification(event, mastodon, reason)

      {:error, :edit = reason} ->
        dismiss_notification(event, mastodon, reason)

      {:error, :no_links = reason} ->
        dismiss_notification(event, mastodon, reason)

      {:error, reason} ->
        with :ok <- dismiss_notification(event, mastodon, inspect(reason)), do: {:error, reason}
    end
  end

  @spec dismiss_notification(map(), Embot.Mastodon.t(), String.t() | atom()) ::
          :ok | {:error, term()}
  defp dismiss_notification(event, mastodon, reason) do
    notification_id = Map.fetch!(event, "id")

    Logger.notice("dismissing notification",
      id: notification_id,
      reason: reason,
      url: get_in(event, ["status", "url"])
    )

    with {:ok, %{status: status}} <- Mastodon.notification_dismiss(mastodon.auth, notification_id) do
      case status do
        200 -> :ok
        404 -> :ok
        status -> {:error, "got unexpected status: #{status} is neither 200 nor 404"}
      end
    end
  end

  @spec parse_links_and_send_reply!(Embot.Mastodon.t(), map()) ::
          :ok | {:error, :bot | :edit | :no_links | term()}
  defp parse_links_and_send_reply!(mastodon, notification)

  defp parse_links_and_send_reply!(_mastodon, %{"account" => %{"bot" => true}}) do
    {:error, :bot}
  end

  defp parse_links_and_send_reply!(_mastodon, %{"status" => %{"edited_at" => edited}})
       when is_binary(edited) do
    {:error, :edit}
  end

  defp parse_links_and_send_reply!(
         mastodon,
         notif = %{
           "type" => "mention",
           "status" => %{
             "content" => content
           }
         }
       ) do
    content = content |> Floki.parse_document!()

    args = Embot.Command.parse(Floki.text(content))

    links = parse_links(content)

    process_links(mastodon, notif, links, args)
  end

  defp parse_links_and_send_reply!(_mastodon, notification) do
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
      Logger.warning("unknown notification", type: notification["type"])
    else
      Logger.notice(
        "not handling notification",
        id: notification["id"],
        type: notification["type"]
      )
    end

    :ok
  end

  defp process_links(mastodon, notif, links, args)
  defp process_links(_mastodon, _notif, [], _args), do: {:error, :no_links}

  defp process_links(
         mastodon,
         %{
           "account" => %{"acct" => acct},
           "status" => %{
             "id" => status_id,
             "visibility" => visibility
           }
         },
         links,
         args
       ) do
    links_stream =
      links
      |> Enum.sort()
      |> Stream.dedup()
      |> Stream.take(100)

    results =
      Task.Supervisor.async_stream_nolink(
        Embot.HandlerTaskSupervisor,
        links_stream,
        fn link ->
          process_link(%LinkContext{
            mastodon: mastodon,
            acct: acct,
            status_id: status_id,
            visibility: visibility,
            link: link,
            args: args
          })
        end,
        ordered: false,
        timeout: :timer.minutes(2),
        max_concurrency: 4
      )
      |> Stream.filter(fn x -> not match?({:ok, _}, x) end)
      |> Enum.to_list()

    case results do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp process_link(%LinkContext{mastodon: mastodon} = context) do
    Logger.info("processing...", link: context.link)

    with {:ok, twi} <- Embot.Fxtwi.get(mastodon.http, context.link) do
      Logger.debug("got fxtwi response", twi: twi)

      visibility =
        case context.visibility do
          "direct" -> "direct"
          _ -> "unlisted"
        end

      {images, videos} = upload_media!(mastodon.auth, twi)
      Logger.debug("waiting media processing...")

      Enum.each(Stream.concat(images, videos), fn id ->
        wait_media_processing!(mastodon.auth, id)
      end)

      Logger.debug("media ready")

      status =
        """
        @#{context.acct}
        Originally posted #{twi.url}

        #{twi.text}
        """
        |> limit_string(@status_char_limit)

      chunks =
        Stream.concat(
          Stream.chunk_every(images, @attachments_limit),
          Stream.chunk_every(videos, @attachments_limit)
        )

      Enum.reduce(chunks, context.status_id, fn chunk, status_id ->
        %{"id" => id} =
          Mastodon.post_status!(
            mastodon.auth,
            %{
              status: status,
              in_reply_to_id: status_id,
              visibility: visibility,
              media_ids: chunk,
              sensitive: twi.sensitive
            }
            |> args_to_request(context.args)
          )

        id
      end)

      :ok
    end
  end

  defp parse_links(content) do
    links = Floki.attribute(content, "a", "href")
    {twitter_links, other_links} = Enum.split_with(links, &is_twitter_link?/1)

    other_links
    |> Stream.map(&guess_nitter/1)
    |> Stream.filter(&(elem(&1, 0) == :ok))
    |> Stream.map(&elem(&1, 1))
    |> Enum.concat(twitter_links)
  end

  defp is_twitter_link?("https://twitter.com" <> _), do: true
  defp is_twitter_link?("https://x.com" <> _), do: true
  defp is_twitter_link?(_), do: false

  defp guess_nitter("https://" <> _ = link) do
    uri = URI.parse(link)

    if Regex.match?(~r"\/[^\/]+\/status\/\d+", uri.path) do
      {:ok, %{uri | host: "twitter.com"} |> URI.to_string()}
    else
      {:error, {:unexpected_path, uri.path}}
    end
  end

  defp guess_nitter(link), do: {:error, {:unexpected_scheme, link}}

  defp wait_media_processing!(req, media_id, tries \\ 0)
  defp wait_media_processing!(_req, nil, _tries), do: :no_media

  defp wait_media_processing!(_req, _media_id, tries) when tries > 5,
    do: raise("max retries reached")

  defp wait_media_processing!(req, media_id, _) do
    case Mastodon.get_media!(req, media_id) do
      {:processing, _} ->
        :timer.sleep(:timer.seconds(1))
        wait_media_processing!(req, media_id)

      {:ok, _} ->
        :ok
    end
  end

  if Application.compile_env!(:embot, :fs_video) do
    defp upload_video!(req, {url, mime}) do
      Logger.debug("downloading video...", url: url, mime: mime)

      tmp_file_path = "/tmp/video/#{:rand.uniform()}"
      file = File.stream!(tmp_file_path, 4096)

      %{status: 200, headers: video_headers} =
        Req.get!(req, url: url, redirect: false, auth: "", into: file)

      content_type = mime || first_or_nil(video_headers, "video/mp4")
      multipart = {file, content_type: content_type, filename: url}

      Logger.debug("uploading video...",
        url: url,
        mime: mime,
        size: File.stat!(tmp_file_path).size
      )

      %{"id" => id} = Mastodon.upload_media!(req, file: multipart)

      File.rm!(tmp_file_path)

      id
    end
  else
    defp upload_video!(req, {url, mime}) do
      Logger.debug("downloading video...", url: url, mime: mime)

      %{status: 200, body: video_binary, headers: video_headers} =
        Req.get!(req, url: url, redirect: false, auth: "")

      content_type = mime || first_or_nil(video_headers, "video/mp4")
      file = {video_binary, content_type: content_type, filename: url}

      Logger.debug("uploading video...",
        url: url,
        mime: mime,
        size: byte_size(video_binary)
      )

      %{"id" => id} = Mastodon.upload_media!(req, file: file)

      id
    end
  end

  defp upload_image!(req, url) do
    %{status: 200, body: image, headers: %{"content-type" => [mime]}} =
      Req.get!(url: url, redirect: false, auth: "")

    %{"id" => id} =
      Mastodon.upload_media!(req, file: {image, content_type: mime, filename: url})

    id
  end

  # mastodon does not allow mixing video and images :(
  @spec upload_media!(Req.Request.t(), Embot.Fxtwi.t()) :: {[String.t()], [String.t()]}
  defp upload_media!(%Req.Request{} = req, %{videos: videos, images: images}) do
    Logger.debug("uploading media", images: inspect(images), videos: inspect(videos))

    {
      Enum.map(images, &upload_image!(req, &1)),
      Enum.map(videos, &upload_video!(req, &1))
    }
  end

  @spec first_or_nil(%{String.t() => [String.t()]}, String.t()) :: String.t() | nil
  defp first_or_nil(headers_map, name)

  defp first_or_nil(nil, _name), do: nil

  defp first_or_nil(headers_map, name) do
    val = get_in(headers_map, [name])

    if val == nil do
      nil
    else
      val |> Enum.at(0, nil)
    end
  end

  defp limit_string(str, max) when max > 1 do
    if String.length(str) <= max do
      str
    else
      str |> String.slice(0, max - 1) |> Kernel.<>("…")
    end
  end

  defp args_to_request(%{} = data, args) do
    Enum.reduce(args, data, fn
      {:cw, nil}, acc ->
        Map.put(acc, :sensitive, true)

      {:cw, spoiler_text}, acc ->
        acc
        |> Map.put(:sensitive, true)
        |> Map.put(:spoiler_text, spoiler_text)
    end)
  end
end
