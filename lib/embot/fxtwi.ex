defmodule Embot.Fxtwi do
  @type t() :: %{
          text: String.t(),
          url: String.t(),
          video: nil | String.t(),
          image: nil | String.t(),
          video_mime: nil | String.t()
        }

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

  @spec get(Req.Request.t(), String.t()) :: {:ok, Embot.Fxtwi.t()} | {:error, term()}
  def get(req, url) do
    with {:ok, url} <- patch_url(url),
         {:ok, tweet} <- do_get(req, url) do
      {:ok, parse(tweet)}
    end
  end

  @spec do_get(Req.Request.t(), String.t()) :: {:ok, map()} | {:error, {number(), String.t()}}
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

  @spec parse(map()) :: Embot.Fxtwi.t()
  def parse(%{
        "url" => url,
        "text" => text,
        "media" => media
      }) do
    image =
      case media["mosaic"] do
        [mosaic | _] ->
          mosaic["formats"]["jpeg"]

        _ ->
          case media["photos"] do
            [photo | _] -> photo["url"]
            _ -> nil
          end
      end

    {video, video_mime} =
      case media["videos"] do
        [
          %{
            "url" => url,
            "format" => mime
          }
          | _
        ] ->
          {url, mime}

        _ ->
          {nil, nil}
      end

    %{
      video: video,
      text: text,
      url: url,
      image: image,
      video_mime: video_mime
    }
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
