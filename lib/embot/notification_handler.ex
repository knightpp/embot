defmodule Embot.NotificationHandler do
  require Logger
  alias Embot.Mastodon

  def handle_sse(sse_data, req) do
    Embot.Sse.parse!(sse_data)
    |> Stream.filter(fn {key, _} -> key == :data end)
    |> Enum.each(fn {_, data} -> process_mention(data, req) end)
  end

  def process_mention(data, req) do
    status = Map.fetch!(data, "status")
    notification_id = data |> Map.fetch!("id")

    content = status |> Map.fetch!("content") |> Floki.parse_document!()
    links = content |> Floki.attribute("a[href*='x.com/i/status']", "href") |> Enum.take(1)

    case links do
      [] ->
        on_empty_links(req, data, status)

      [link] ->
        dbg(link)
        fxlink = %URI{URI.parse(link) | host: "fixupx.com"} |> URI.to_string()
        dbg(fxlink)
        twi = get_fxtwitter_ogp!(fxlink)
        dbg(twi)

        opts =
          case upload_media(req, twi) do
            nil -> []
            id -> [media_ids: id]
          end

        opts =
          Keyword.merge(opts,
            status: "Originally posted #{twi.url}\n\n#{twi.title}\n\n#{twi.description}",
            visibility: "unlisted"
          )

        Mastodon.post_status!(req, opts)
    end

    Logger.info("dismissing notification id=#{notification_id}")
    :ok = Mastodon.notification_dismiss!(req, notification_id)
    :timer.sleep(1000)

    {:noreply, req}
  end

  defp on_empty_links(req, data, status) do
    status_id = status |> Map.fetch!("id")
    visibility = status |> Map.fetch!("visibility")
    account = data |> Map.fetch!("account") |> Map.fetch!("acct")

    Logger.info("replying to #{status_id}")

    Mastodon.post_status!(
      req,
      status: "@#{account} hello! I do not work without x[dot]com links :(",
      in_reply_to_id: status_id,
      visibility: visibility
    )
  end

  defp upload_media(req, %{video: video, image: image}) when video != nil do
    %{status: 200, body: thumbnail} = Req.get!(url: image, redirect: false)

    # did not work with into: :self
    %{status: 200, body: video_binary, headers: %{"content-type" => [mime]}} =
      Req.get!(url: video, redirect: false)

    %{"id" => id} =
      Mastodon.upload_media!(req,
        file: {video_binary, content_type: mime},
        thumbnail: thumbnail
      )

    id
  end

  defp upload_media(_req, _), do: nil

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
