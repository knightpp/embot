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
    case patch_url(link) do
      {:ok, patched} -> patched
      {:error, term} -> raise term
    end
  end

  def patch_url(link) do
    uri = URI.parse(link)

    case uri.host do
      "x.com" -> {:ok, %URI{uri | host: "fixupx.com"} |> URI.to_string()}
      "twitter.com" -> {:ok, %URI{uri | host: "fxtwitter.com"} |> URI.to_string()}
      host -> {:error, "unknown host=#{host} of link=#{link}"}
    end
  end

  @spec get(Req.Request.t(), String.t()) :: {:ok, Embot.Fxtwi.t()} | {:error, term()}
  def get(req, url) do
    with {:ok, url} <- patch_url(url),
         {:ok, body} <- do_get(req, url) do
      parse(body)
    end
  end

  defp do_get(req, url) do
    %{status: status, body: body} =
      Req.get!(req, url: url, redirect: false, user_agent: "curl", auth: "")

    if status == 200 do
      {:ok, body}
    else
      {:error, {status, body}}
    end
  end

  @spec parse(binary()) :: {:ok, Embot.Fxtwi.t()} | {:error, term()}
  def parse(body) do
    with {:ok, document} <- body |> Floki.parse_document(),
         {:ok, url} = attribute(document, "meta[property='og:url'][content]"),
         {:ok, description} = attribute(document, "meta[property='og:description'][content]"),
         {:ok, title} = attribute(document, "meta[property='og:title'][content]") do
      image =
        attributeOrNil(document, "meta[property='og:image'][content]") |> try_strip_redirect!()

      video =
        attributeOrNil(document, "meta[property='og:video'][content]") |> try_strip_redirect!()

      video_mime =
        attributeOrNil(document, [
          "meta[property='og:video:type'][content]",
          "meta[property='twitter:player:stream:content_type'][content]"
        ])

      {:ok,
       %{
         video: video,
         description: description,
         url: url,
         title: title,
         image: image,
         video_mime: video_mime
       }}
    end
  end

  @spec strip_redirect!(String.t()) :: String.t()
  def strip_redirect!(url) when is_binary(url) do
    uri = URI.new!(url)

    if uri.query == nil do
      url
    else
      case URI.decode_query(uri.query) do
        %{"url" => redirect} -> redirect
        _ -> url
      end
    end
  end

  defp try_strip_redirect!(nil), do: nil
  defp try_strip_redirect!(url), do: strip_redirect!(url)

  defp attributeOrNil(document, attributes) when is_list(attributes) do
    Enum.find_value(attributes, fn attr ->
      document |> Floki.attribute(attr, "content") |> first()
    end)
  end

  defp attributeOrNil(document, attr) do
    document |> Floki.attribute(attr, "content") |> first()
  end

  defp attribute(document, attributes) do
    case attributeOrNil(document, attributes) do
      nil ->
        {:error, {"unexpected nil while getting #{inspect(attributes)}", document}}

      v ->
        {:ok, v}
    end
  end

  defp first([]), do: nil
  defp first([a | _]), do: a
end
