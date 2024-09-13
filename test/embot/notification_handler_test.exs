defmodule Embot.NotificationHandlerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  alias Embot.NotificationHandler

  setup do
    Req.Test.verify_on_exit!()
  end

  test "when unknown notification type" do
    Req.Test.expect(NotifHandler, &Req.Test.json(&1, %{}))
    req = Req.new(plug: {Req.Test, NotifHandler})
    map = %{"id" => 42, "type" => :test}

    log_lines =
      capture_log(fn ->
        NotificationHandler.process_mention(map, req)
      end)

    assert log_lines =~ "notification type=test is unknown"
    assert log_lines =~ "dismissing notification id=42"
  end

  test "when notification from bot" do
    Req.Test.expect(NotifHandler, &Req.Test.json(&1, %{}))
    req = Req.new(plug: {Req.Test, NotifHandler})
    map = %{"id" => 42, "account" => %{"bot" => true, "acct" => "test"}}

    log_lines =
      capture_log(fn ->
        NotificationHandler.process_mention(map, req)
      end)

    assert log_lines =~ "got a message from bot! @test"
    assert log_lines =~ "dismissing notification id=42"
  end

  test "when no links" do
    Req.Test.expect(NotifHandler, &Req.Test.json(&1, %{}))
    req = Req.new(plug: {Req.Test, NotifHandler})

    map = %{
      "id" => 42,
      "account" => %{"acct" => "test"},
      "type" => "mention",
      "status" => %{
        "id" => 4242,
        "content" => """
          <a href="https://notx.com/path1/f">Link 1</a>
          <a href="https://nottwitter.com/path1/f">Link 1</a>

          https://nitter.com lorem ipsum sit dolor
        """,
        "visibility" => "public"
      }
    }

    log_lines =
      capture_log(fn ->
        NotificationHandler.process_mention(map, req)
      end)

    assert log_lines =~ "no links in 4242"
    assert log_lines =~ "dismissing notification id=42"
  end

  @tag capture_log: true
  test "when there are no ogp" do
    Req.Test.expect(NotifHandler, 2, fn conn ->
      case Plug.Conn.request_url(conn) do
        "https://fxtwitter.com/b" -> Req.Test.html(conn, "")
        "https://fixupx.com/a" -> Req.Test.html(conn, "")
      end
    end)

    # Req.Test.expect(NotifHandler, &Req.Test.html(&1, ""))
    req = Req.new(plug: {Req.Test, NotifHandler})

    map = %{
      "id" => 42,
      "account" => %{"acct" => "test"},
      "type" => "mention",
      "status" => %{
        "id" => 4242,
        "content" => """
          <a href="https://x.com/a">Link 1</a>
          <a href="https://twitter.com/b">Link 2</a>
        """,
        "visibility" => "public"
      }
    }

    assert {:error, errors} = NotificationHandler.process_mention(map, req)

    for {error, _} <- errors do
      assert %RuntimeError{
               message: "unexpected nil while getting \"meta[property='og:url'][content]\""
             } == error
    end
  end
end
