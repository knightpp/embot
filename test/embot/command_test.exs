defmodule Embot.CommandTest do
  use ExUnit.Case, async: true
  alias Embot.Command

  test "cw with arg" do
    assert {:ok, [cw: "hello world"], _, _, _, _} =
             Command.command(~s/@bot@example.com -cw="hello world"/)
  end

  test "cw without arg" do
    assert {:ok, [cw: nil], _, _, _, _} = Command.command(~s/@bot@example.com -cw @foo@bar.baz"/)
  end

  test "no command" do
    assert {:error, _, _, _, _, _} = Command.command(~s/@bot@example.com\n@foo@bar.baz"/)
  end

  test "cw with empty arg" do
    assert {:ok, [cw: nil], _, _, _, _} =
             Command.command(~s/@bot@example.com -cw="" @foo@bar.baz"/)
  end
end
