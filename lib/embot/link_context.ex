defmodule Embot.NotificationHandler.LinkContext do
  defstruct [
    :mastodon,
    :link,
    :status_id,
    :visibility,
    :acct,
    :args
  ]
end
