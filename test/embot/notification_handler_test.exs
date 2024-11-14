defmodule Embot.NotificationHandlerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  alias Embot.NotificationHandler

  @html File.read!("test/data/gif.html")

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "should always dismiss notification" do
    setup do
      Req.Test.expect(NotifHandler, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v1/notifications/42/dismiss"
        Req.Test.json(conn, %{})
      end)

      :ok
    end

    test "when unknown notification type" do
      req = Req.new(plug: {Req.Test, NotifHandler})
      map = %{"id" => 42, "type" => :test}

      log_lines =
        capture_log(fn ->
          NotificationHandler.process_mention(map, req)
        end)

      assert log_lines =~ "unknown notification type=test"
      assert log_lines =~ "dismissing notification id=42 reason=ok"
    end

    test "when notification from bot" do
      req = Req.new(plug: {Req.Test, NotifHandler})
      map = %{"id" => 42, "account" => %{"bot" => true, "acct" => "test"}}

      log_lines =
        capture_log(fn ->
          NotificationHandler.process_mention(map, req)
        end)

      assert log_lines =~ "dismissing notification id=42 reason=bot"
    end

    test "when no links" do
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

      assert log_lines =~ "dismissing notification id=42 reason=no_links"
    end

    test "when no edited message" do
      req = Req.new(plug: {Req.Test, NotifHandler})

      map = %{
        "id" => 42,
        "type" => "mention",
        "status" => %{
          "edited_at" => "today"
        }
      }

      log_lines =
        capture_log(fn ->
          NotificationHandler.process_mention(map, req)
        end)

      assert log_lines =~ "dismissing notification id=42 reason=edit"
    end
  end

  @tag capture_log: true
  test "when there are no ogp" do
    Req.Test.expect(NotifHandler, 2, fn conn ->
      case Plug.Conn.request_url(conn) do
        "https://fxtwitter.com/b" -> Req.Test.html(conn, "")
        "https://fixupx.com/a" -> Req.Test.html(conn, "")
      end
    end)

    Req.Test.expect(NotifHandler, &Req.Test.html(&1, ""))
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

    for {:exit, [error]} <- errors do
      assert {:exit,
              %RuntimeError{
                message: "unexpected nil while getting \"meta[property='og:url'][content]\""
              }} = error
    end
  end

  @tag capture_log: true
  test "it works" do
    Req.Test.expect(NotifHandler, 9, fn conn ->
      case Plug.Conn.request_url(conn) do
        "https://fxtwitter.com/b" -> Req.Test.html(conn, @html)
        "https://fixupx.com/a" -> Req.Test.html(conn, @html)
        "http://www.example.com/api/v2/media" -> Req.Test.json(conn, %{"id" => 1})
        "http://www.example.com/api/v1/media/1" -> Req.Test.json(conn, %{})
        "http://www.example.com/api/v1/statuses" -> Req.Test.json(conn, %{})
        "http://www.example.com/api/v1/notifications/42/dismiss" -> Req.Test.json(conn, %{})
        url -> flunk("Unexpected url #{url}")
      end
    end)

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

    assert :ok = NotificationHandler.process_mention(map, req)
  end
end
