defmodule Embot.Mastodon do
  def new(url, access_token) do
    Req.new(base_url: url, auth: {:bearer, access_token})
    |> Req.Request.put_header("user-agent", "Embot")
  end

  def verify_credentials!(req) do
    %{status: 200, body: body} = Req.get!(req, url: "api/v1/apps/verify_credentials")
    body
  end

  def upload_media!(req, data) do
    # status may be 200 or 202
    %{body: body} =
      Req.post!(req, url: "/api/v2/media", form_multipart: data)

    body
  end

  def stream_notifications!(req, into) do
    Req.get!(req,
      url: "/api/v1/streaming/user/notification",
      into: into,
      receive_timeout: :timer.seconds(90)
    )
  end

  def notification_dismiss!(req, notification_id) do
    %{status: 200} =
      Req.post!(req,
        url: "/api/v1/notifications/:id/dismiss",
        path_params: [id: notification_id]
      )

    :ok
  end

  def post_status!(req, form_data) do
    # req = Req.Request.put_new_header(req, "idempotency-key", to_string(:erlang.phash2(form_data)))

    %{status: 200, body: body} =
      Req.post!(req,
        url: "/api/v1/statuses",
        form: form_data
      )

    body
  end

  def oauth_token!(req, client_id, client_secret) do
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

  def notifications!(req, query_params \\ []) do
    %{status: 200, body: body} = Req.get!(req, url: "/api/v1/notifications", params: query_params)
    body
  end
end
