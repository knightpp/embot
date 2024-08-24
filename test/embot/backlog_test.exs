defmodule Embot.BacklogTest do
  use ExUnit.Case, async: true
  alias Embot.Backlog
  @moduletag capture_log: true

  setup do
    Req.Test.verify_on_exit!()
  end

  test "empty mentions" do
    Req.Test.expect(Backlog, &Req.Test.json(&1, []))
    req = Req.new(plug: {Req.Test, Backlog})

    Backlog.run(req, nil)
  end

  test "one mention" do
    Req.Test.expect(Backlog, &Req.Test.json(&1, [""]))
    req = Req.new(plug: {Req.Test, Backlog})

    Backlog.run(req, fn {:mention, ""} -> :ok end)
  end

  test "multiple mentions" do
    Req.Test.expect(Backlog, &Req.Test.json(&1, ["1", "2", "3"]))
    req = Req.new(plug: {Req.Test, Backlog})

    Backlog.run(req, fn {:mention, data} ->
      case data do
        "1" -> :ok
        "2" -> :ok
        "3" -> :ok
      end
    end)
  end
end
