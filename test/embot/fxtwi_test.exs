defmodule Embot.FxtwiTest do
  use ExUnit.Case, async: true
  alias Embot.Fxtwi

  @gif_json File.read!("./test/data/gif.json")

  test "parse gif" do
    assert %{"tweet" => tweet} = Jason.decode!(@gif_json)

    assert %{
             text: "Secret Attic  #pixelart",
             images: [],
             mosaics: [],
             url: "https://twitter.com/d4frdm/status/1890373755089662451",
             videos: [{"https://video.twimg.com/tweet_video/Gjv05uxacAAbtze.mp4", "video/mp4"}]
           } = Fxtwi.parse(tweet)
  end

  describe "patch_url!" do
    test "link is x.com" do
      link = Fxtwi.patch_url!("https://x.com/some/user/id")
      assert link == "https://api.fxtwitter.com/some/user/id"
    end

    test "link is twitter.com" do
      link = Fxtwi.patch_url!("https://twitter.com/some/user/id")
      assert link == "https://api.fxtwitter.com/some/user/id"
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

  describe "strip redirect" do
    test "when strips" do
      want =
        "https://video.twimg.com/ext_tw_video/1848892096964358144/pu/vid/avc1/718x708/wmPO1HX1IZRNfJYN.mp4?tag=12"

      got =
        "https://api.fxtwitter.com/2/go?url=https%3A%2F%2Fvideo.twimg.com%2Fext_tw_video%2F1848892096964358144%2Fpu%2Fvid%2Favc1%2F718x708%2FwmPO1HX1IZRNfJYN.mp4%3Ftag%3D12"

      assert Fxtwi.strip_redirect!(got) == want
    end

    test "when does not strip" do
      got = "https://example.com/"
      want = got

      assert Fxtwi.strip_redirect!(got) == want
    end
  end
end
