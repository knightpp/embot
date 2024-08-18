defmodule Embot.Fxtwi do
  @type t() :: %{
          title: String.t(),
          description: String.t(),
          url: String.t(),
          video: nil | String.t(),
          image: nil | String.t(),
          video_mime: nil | String.t()
        }

  def patch_url!(link) do
    url = URI.parse(link)

    patched =
      case url.host do
        "x.com" -> %URI{url | host: "fixupx.com"}
        "twitter.com" -> %URI{url | host: "fxtwitter.com"}
      end

    URI.to_string(patched)
  end

  @spec get!(String.t()) :: Embot.Fxtwi.t()
  def get!(url) do
    url = patch_url!(url)
    %{status: 200, body: body} = Req.get!(url: url, redirect: false, user_agent: "curl")
    parse!(body)
  end

  @spec parse!(binary()) :: Embot.Fxtwi.t()
  def parse!(body) do
    document = body |> Floki.parse_document!()

    url = attribute!(document, "meta[property='og:url'][content]")
    description = attribute!(document, "meta[property='og:description'][content]")
    title = attribute!(document, "meta[property='og:title'][content]")
    image = attribute(document, "meta[property='og:image'][content]")
    video = attribute(document, "meta[property='og:video'][content]")

    video_mime =
      attribute(document, [
        "meta[property='og:video:type'][content]",
        "meta[property='twitter:player:stream:content_type'][content]"
      ])

    %{
      video: video,
      description: description,
      url: url,
      title: title,
      image: image,
      video_mime: video_mime
    }
  end

  defp attribute(document, attributes) when is_list(attributes) do
    Enum.find_value(attributes, fn attr ->
      document |> Floki.attribute(attr) |> first()
    end)
  end

  defp attribute(document, attr) do
    document |> Floki.attribute(attr) |> first()
  end

  defp attribute!(document, attributes) do
    attribute(document, attributes) || raise "unexpected nil while getting #{inspect(attributes)}"
  end

  defp first([]), do: nil
  defp first([a | _]), do: a
end
