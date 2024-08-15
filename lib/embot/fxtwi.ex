defmodule Embot.Fxtwi do
  @type t() :: %{
          title: String.t(),
          description: String.t(),
          url: String.t(),
          video: nil | String.t(),
          image: nil | String.t()
        }

  @spec get!(String.t()) :: Embot.Fxtwi.t()
  def get!(url) do
    %{status: 200, body: body} = Req.get!(url: url, redirect: false, user_agent: "curl")
    parse!(body)
  end

  @spec parse!(binary()) :: Embot.Fxtwi.t()
  def parse!(body) do
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

    %{
      video: video,
      description: description,
      url: original_url,
      title: title,
      image: image
    }
  end

  defp first([]), do: nil
  defp first([a | _]), do: a

  defp first!([a | _]), do: a
end
