defmodule Embot.FxtwiTest do
  use ExUnit.Case, async: true
  alias Embot.Fxtwi

  @body File.read!("./test/data/gif.html")

  test "parse gif" do
    assert Fxtwi.parse!(@body) == %{
             description: "そろそろ扇風機も買い換えたい\nおはよう🌞ございます",
             image: "https://pbs.twimg.com/tweet_video_thumb/GU-mr7Na4AQovSJ.jpg",
             title: "サカイタカヒロ (@sakai_tak)",
             url: "https://twitter.com/sakai_tak/status/1823859660111392964",
             video: "https://gif.fxtwitter.com/tweet_video/GU-mr7Na4AQovSJ.mp4",
             video_mime: "video/mp4"
           }
  end

  describe "patch_url!" do
    test "link is x.com" do
      link = Fxtwi.patch_url!("https://x.com/some/user/id")
      assert link == "https://fixupx.com/some/user/id"
    end

    test "link is twitter.com" do
      link = Fxtwi.patch_url!("https://twitter.com/some/user/id")
      assert link == "https://fxtwitter.com/some/user/id"
    end

    test "link is example.com" do
      execute = fn -> Fxtwi.patch_url!("http://example.com") end
      assert_raise(RuntimeError, ~r/^unknown/, execute)
    end

    test "link is empty" do
      execute = fn -> Fxtwi.patch_url!("") end
      assert_raise(RuntimeError, ~r/^unknown/, execute)
    end
  end
end
