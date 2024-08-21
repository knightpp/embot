defmodule Embot.SseTest do
  use ExUnit.Case, async: true

  alias Embot.Sse

  test "parse empty string" do
    list = Sse.parse("") |> Enum.to_list()
    assert list == []
  end

  test "parse single line" do
    list = Sse.parse("event: notification\n") |> Enum.to_list()
    assert list == [{:ok, {:event, "notification"}}]
  end

  test "parse multiple lines" do
    list = Sse.parse("event: notification\ndata: 0\ndata: 1") |> Enum.to_list()
    assert list == [event("notification"), data(0), data(1)]
  end

  test "accumulate empty" do
    result = Sse.accumulate([], "")
    assert result == {[], [""]}
  end

  test "accumulate single line" do
    result = Sse.accumulate([], "event: first\n")
    assert result == {[], ["event: first\n"]}
  end

  test "accumulate multiple lines" do
    assert {[], acc} = Sse.accumulate([], "event: first\n")
    assert {[], acc} = Sse.accumulate(acc, "event: second\n")
    assert {[], acc} = Sse.accumulate(acc, "event: third\n")
    assert ^acc = ["event: first\nevent: second\nevent: third\n"]
  end

  test "accumulate ready" do
    assert {[], acc} = Sse.accumulate([], "event: first\n")
    assert {[], acc} = Sse.accumulate(acc, "event: second\n")
    assert {[], acc} = Sse.accumulate(acc, "event: third\n")
    assert {["event: first\nevent: second\nevent: third"], ["\n"]} = Sse.accumulate(acc, "\n\n")
  end

  test "accumulate two messages" do
    assert {[], acc} = Sse.accumulate([], "event: first\n")

    assert {["event: first\nevent: second"], acc} =
             Sse.accumulate(acc, "event: second\n\n\nevent: third\n")

    assert {["\nevent: third"], ["\n"]} = Sse.accumulate(acc, "\n\n")
  end

  test "parse comment" do
    assert [{:ok, {:comment, "hah this is comment"}}] =
             Sse.parse(": hah this is comment") |> Enum.to_list()

    assert [{:ok, {:comment, ""}}] = Sse.parse(":") |> Enum.to_list()
    assert [{:ok, {:comment, "no space"}}] = Sse.parse(":no space") |> Enum.to_list()
  end

  test "parse id" do
    assert [{:ok, {:id, "test"}}] = Sse.parse("id: test") |> Enum.to_list()
  end

  test "parse retry" do
    assert [{:ok, {:retry, "test"}}] = Sse.parse("retry: test") |> Enum.to_list()
  end

  test "parse unknown key error" do
    assert [{:error, :unknown_key}] = Sse.parse("does not exists: test") |> Enum.to_list()
  end

  test "parse no semicolon error" do
    assert [{:error, :no_semicolon}] = Sse.parse("does not have semicolon") |> Enum.to_list()
  end

  defp event(value) do
    {:ok, {:event, value}}
  end

  defp data(value) do
    {:ok, {:data, value}}
  end
end
