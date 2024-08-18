defmodule Embot.FxtwiTest do
  alias Embot.Fxtwi
  use ExUnit.Case

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
end
