defmodule Embot.Mastodon do
  alias Embot.Mastodon
  @enforce_keys [:http, :auth, :url, :token]
  defstruct [:http, :auth, :url, :token]

  @type t() :: %Mastodon{}

  @spec new(String.t(), String.t()) :: Mastodon.t()
  def new(url, access_token, base \\ Req.new()) do
    req = base |> Req.Request.put_header("user-agent", "Embot")

    %Embot.Mastodon{
      http: req,
      auth: Req.merge(req, base_url: url, auth: {:bearer, access_token}),
      url: url,
      token: access_token
    }
  end

  def verify_credentials!(%Req.Request{} = req) do
    %{status: 200, body: body} = Req.get!(req, url: "api/v1/apps/verify_credentials")
    body
  end

  def upload_media(%Req.Request{} = req, data) do
    with {:ok, %{status: status, body: body, headers: headers}} =
           Req.post(req, url: "/api/v2/media", form_multipart: data, retry: :transient) do
      case status do
        200 ->
          {:ok, body}

        202 ->
          {:ok, body}

        429 ->
          {:error, {"rate limited", headers}}

        status ->
          {
            :error,
            # TODO: didn't work
            # %Embot.Mastodon.Error{
            %{
              message: "unexpected status code",
              body: body,
              status: status
            }
          }
      end
    end
  end

  def upload_media!(%Req.Request{} = req, data) do
    case Req.post!(req, url: "/api/v2/media", form_multipart: data) do
      %{status: 200, body: body} -> body
      %{status: 202, body: body} -> body
    end
  end

  def stream_notifications!(%Req.Request{} = req, into, opts \\ []) do
    req
    |> Req.Request.put_headers([
      {"content-type", "text/event-stream; charset=utf-8"},
      {"cache-control", "no-cache"},
      {"connection", "keep-alive"}
    ])
    |> Req.get!(
      Keyword.merge(
        [
          url: "/api/v1/streaming/user/notification",
          into: into,
          receive_timeout: :timer.seconds(90)
        ],
        opts
      )
    )
  end

  def notification_dismiss(%Req.Request{} = req, notification_id) do
    Req.post(req,
      url: "/api/v1/notifications/:id/dismiss",
      path_params: [id: notification_id],
      retry: :transient
    )
  end

  def post_status!(%Req.Request{} = req, %{} = data) do
    # req = Req.Request.put_new_header(req, "idempotency-key", to_string(:erlang.phash2(form_data)))

    %{status: 200, body: body} =
      Req.post!(req,
        url: "/api/v1/statuses",
        json: data
      )

    body
  end

  def get_media!(%Req.Request{} = req, id) do
    %{status: status, body: body} =
      Req.get!(req,
        url: "/api/v1/media/:id",
        path_params: [id: id]
      )

    case status do
      206 ->
        {:processing, body}

      200 ->
        {:ok, body}
    end
  end

  def oauth_token!(%Req.Request{} = req, client_id, client_secret) do
    %{status: 200, body: body} =
      Req.post!(req,
        url: "/oauth/token",
        form: [
          client_id: client_id,
          client_secret: client_secret,
          redirect_uri: "urn:ietf:wg:oauth:2.0:oob",
          grant_type: "client_credentials"
        ]
      )

    %{
      access_token: Map.fetch!(body, "access_token"),
      token_type: Map.fetch!(body, "token_type"),
      scope: Map.fetch!(body, "scope"),
      created_at: Map.fetch!(body, "created_at")
    }
  end

  def notifications!(%Req.Request{} = req, query_params \\ []) do
    %{status: 200, body: body} = Req.get!(req, url: "/api/v1/notifications", params: query_params)
    body
  end

  def get_status(%Req.Request{} = req, id) do
    Req.get!(req, url: "/api/v1/statuses/:id", path_params: [id: id])
    |> get_status_parse()
  end

  defp get_status_parse(%{status: 200, body: status}), do: {:ok, status}
  defp get_status_parse(%{body: err}), do: {:error, inspect(err)}
end

defmodule Embot.Mastodon.Error do
  defexception [:message, :body, :status]

  @impl true
  def message(%{message: msg, body: body, status: status}) do
    """
      Msg: #{msg}
      Status: #{status}
      Body: #{body}
    """
  end
end
