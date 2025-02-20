defmodule Embot.Fxtwi do
  @type mime() :: String.t()
  @type t() :: %Embot.Fxtwi{
          text: String.t(),
          url: String.t(),
          videos: [{String.t(), mime()}],
          images: [String.t()],
          mosaics: [String.t()]
        }
  defstruct text: nil, url: nil, videos: [], images: [], mosaics: []

  @user_agent "embot/fxtwi"

  @spec patch_url!(String.t()) :: String.t()
  def patch_url!(link) do
    case patch_url(link) do
      {:ok, patched} -> patched
      {:error, term} -> raise term
    end
  end

  @spec patch_url(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def patch_url(link) do
    uri = URI.parse(link)

    case uri.host do
      "x.com" -> {:ok, %URI{uri | host: "api.fxtwitter.com"} |> URI.to_string()}
      "twitter.com" -> {:ok, %URI{uri | host: "api.fxtwitter.com"} |> URI.to_string()}
      host -> {:error, "unknown host=#{host} of link=#{link}"}
    end
  end

  @spec get(Req.Request.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def get(req, url) do
    with {:ok, url} <- patch_url(url),
         {:ok, tweet} <- do_get(req, url) do
      {:ok, parse(tweet)}
    end
  end

  @spec do_get(Req.Request.t(), String.t()) :: {:ok, t()} | {:error, {number(), String.t()}}
  defp do_get(req, url) do
    %{
      status: status,
      body: %{
        "message" => msg,
        "tweet" => tweet
      }
    } =
      Req.get!(req, url: url, redirect: false, user_agent: @user_agent, auth: "")

    if status == 200 do
      {:ok, tweet}
    else
      {:error, {status, msg}}
    end
  end

  @spec parse(map()) :: t()
  def parse(tweet)

  def parse(
        %{
          "url" => url,
          "text" => text,
          "quote" =>
            %{"author" => %{"name" => quote_author}, "text" => quote_text, "url" => quote_url} =
              quote
        } = tweet
      ) do
    pretty_quote_text =
      quote_text
      |> String.splitter("\n")
      |> Stream.map(fn line -> "> #{line}" end)
      |> Enum.join()

    text =
      """
      #{text}

      Quoting #{quote_author} #{quote_url}
      #{pretty_quote_text}
      """

    parse_media(
      %Embot.Fxtwi{
        text: text,
        url: url
      },
      tweet["media"]
    )
    |> parse_media(quote["media"])
  end

  def parse(%{
        "url" => url,
        "text" => text,
        "media" => media
      }) do
    parse_media(
      %Embot.Fxtwi{
        text: text,
        url: url
      },
      media
    )
  end

  defp parse_media(acc, media)

  defp parse_media(acc, nil) do
    acc
  end

  defp parse_media(acc, media) do
    videos =
      Map.get(media, "videos", [])
      |> Stream.map(fn %{"url" => url, "format" => mime} -> {url, mime} end)
      |> then(&Enum.concat(acc.videos, &1))

    mosaics =
      case get_in(media, ["mosaic", "formats", "jpeg"]) do
        nil -> []
        str -> [str]
      end
      |> then(&Enum.concat(acc.mosaics, &1))

    images =
      media
      |> Map.get("photos", [])
      |> Stream.map(fn %{"url" => url} -> url end)
      # accumulator takes priority
      |> then(&Enum.concat(acc.images, &1))

    Map.merge(
      acc,
      %{
        videos: videos,
        mosaics: mosaics,
        images: images
      }
    )
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
end
