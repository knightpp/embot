defmodule Embot.Streamer.ProducerTest do
  use ExUnit.Case, async: true

  @moduletag capture_log: true

  setup do
    %{url: url} =
      TestHelper.start_http_server(fn conn ->
        conn = Plug.Conn.send_chunked(conn, 200)
        {:ok, conn} = Plug.Conn.chunk(conn, "foo\n\n")
        {:ok, conn} = Plug.Conn.chunk(conn, "bar")
        {:ok, conn} = Plug.Conn.chunk(conn, "\n\nbaz\n\n")
        conn
      end)

    req = Req.new(base_url: url)

    pid = start_supervised!({Embot.Streamer.Producer, req}, restart: :transient)
    %{pid: pid}
  end

  test "receive and accumulate chunks", %{pid: pid} do
    msgs = GenStage.stream([{pid, cancel: :transient}]) |> Stream.take(3) |> Enum.to_list()
    assert Enum.sort(msgs) == Enum.sort(["foo", "bar", "baz"])
  end
end
