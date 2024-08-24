defmodule Embot.StreamerTest do
  use ExUnit.Case

  setup do
    Req.Test.set_req_test_to_shared()

    Req.Test.stub(__MODULE__, fn conn ->
      conn = Plug.Conn.send_chunked(conn, 200)
      {:ok, conn} = Plug.Conn.chunk(conn, "event: notification\n\n\n")
      conn
    end)

    req = Req.new(plug: {Req.Test, __MODULE__})

    start_link_supervised!({Embot.Streamer.Producer, req})
    :ok
  end

  # test "foo" do
  #   :timer.sleep(2000)
  # end
end
