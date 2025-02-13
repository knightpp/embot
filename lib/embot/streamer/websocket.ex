defmodule Embot.Streamer.Websocket do
  require Logger
  use Fresh

  def handle_connect(_status, _headers, state) do
    {:ok, state}
  end

  def handle_in({_, payload}, _state) do
    process_message(Jason.decode!(payload))
  end

  defp process_message(%{
         "stream" => ["user:notification"],
         "event" => "notification",
         "payload" => notification
       }) do
    notification = Jason.decode!(notification)
    Embot.Streamer.WebsocketProducer.sync_notify({:mention, notification})
    {:ok, :state}
  end

  defp process_message(%{
         "stream" => stream,
         "event" => event
       }) do
    Logger.warning("unrecognized websocket message stream=#{stream} event=#{event}")
  end
end
