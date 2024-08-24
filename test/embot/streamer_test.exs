defmodule Embot.StreamerTest do
  use ExUnit.Case

  setup do
    Req.Test.set_req_test_to_shared()
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, [])
    end)

    req = Req.new(plug: {Req.Test, __MODULE__})

    start_link_supervised!({Embot.Streamer, req})

    :ok
  end

  # test "foo" do
  #   :timer.sleep(2000)
  # end
end
