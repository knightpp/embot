defmodule Embot.Mastodon.Status do
  @type visibility() :: :public | :unlisted | :private | :direct
  @type t() :: %{
          id: String.t(),
          uri: String.t(),
          created_at: String.t(),
          # account: Mastodon.Account.t(),
          content: String.t(),
          visibility: visibility(),
          sensitive: true | false,
          spoiler_text: String.t()
          # and much more
        }
end
