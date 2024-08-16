defmodule Embot.SseTest do
  use ExUnit.Case, async: true

  alias Embot.Sse

  test "empty string" do
    list = Sse.parse("") |> Enum.to_list()
    assert list == []
  end

  test "event" do
    list = Sse.parse("event: notification\n") |> Enum.to_list()
    assert list == [{:event, "notification"}]
  end
end
