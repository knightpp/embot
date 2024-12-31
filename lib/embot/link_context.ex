defmodule Embot.NotificationHandler.LinkContext do
  defstruct [
    :req,
    :link,
    :status_id,
    :visibility,
    :acct,
    :args
  ]
end
