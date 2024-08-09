defmodule EmbotTest do
  use ExUnit.Case
  doctest Embot

  test "greets the world" do
    assert Embot.hello() == :world
  end
end
