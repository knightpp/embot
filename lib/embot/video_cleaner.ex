defmodule Embot.VideoCleaner do
  use Task, restart: :transient

  def start_link(_) do
    # if Application.fetch_env!(:embot, :fs_video) do
    File.rm_rf!("/tmp/video")
    File.mkdir_p!("/tmp/video")
    # end

    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
  end
end
