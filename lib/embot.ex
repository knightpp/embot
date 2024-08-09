defmodule Embot do
  @authdb "./auth.db"

  def test() do
    req = Req.new(base_url: "https://mastodon.knightpp.cc")

    access_token = Application.fetch_env!(:embot, :access_token)
    # case Embot.Database.get(@authdb) do
    #   {:ok, token} -> token
    #   {:error, _} -> authorize(req)
    # end

    req = Req.merge(req, auth: {:bearer, access_token})
    verify_credentials(req)
    stream_notifications(req)
  end

  def stream_notifications(req) do
    Req.get(req,
      url: "/api/v1/streaming/user/notification",
      into: &process_stream/2,
      receive_timeout: :timer.seconds(90)
    )
  end

  def process_stream({:data, data}, {req, resp}) do
    result =
      Embot.Streaming.Sse.parse(data)
      |> Stream.filter(fn {key, _} -> key == :data end)
      |> Enum.map(fn {_, data} -> Jason.decode!(data) end)

    IO.inspect(result)
    {:cont, {req, resp}}
  end

  defp verify_credentials(req) do
    %{status: 200, body: body} = Req.get!(req, url: "api/v1/apps/verify_credentials")
    body
  end

  defp authorize(req) do
    # Example response
    # {
    #   "access_token": "ZA-Yj3aBD8U8Cm7lKUp-lm9O9BmDgdhHzDeqsY8tlL0",
    #   "token_type": "Bearer",
    #   "scope": "read write follow push",
    #   "created_at": 1573979017
    # }
    %{status: 200, body: body} =
      Req.post!(req,
        url: "/oauth/token",
        form: [
          client_id: Application.fetch_env!(:embot, :client_id),
          client_secret: Application.fetch_env!(:embot, :client_secret),
          redirect_uri: "urn:ietf:wg:oauth:2.0:oob",
          grant_type: "client_credentials"
        ]
      )

    access_token = body["access_token"]
    :ok = Embot.Database.put(@authdb, access_token)
    access_token
  end
end
