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

  @tag :benchmark
  test "benchmark parsing" do
    output =
      Benchee.run(
        %{
          "nimble_parsec" => fn input ->
            Command.command(input)
          end
        },
        inputs: %{
          "small" => ~s/@bot@example.com -cw @foo@bar.baz"/,
          "lorem ipsum" => """
            "Lorem ipssm dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut 
            labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris 
            nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse 
            cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui 
            officia deserunt mollit anim id est laborum.
            -cw mmm long
            "
          """
        }
      )

    results = Enum.at(output.scenarios, 0)
    assert results.run_time_data.statistics.average <= 5_000
  end
end
