defmodule Embot.Streamer.Consumer do
  use GenStage
  require Logger

  def start_link(args) do
    GenStage.start_link(__MODULE__, args)
  end

  @impl GenStage
  def init({mastodon, subscribe_to}) do
    {:consumer, mastodon, subscribe_to: [{subscribe_to, max_demand: 1}]}
  end

  @impl GenStage
  def handle_events(events, _from, mastodon) do
    Enum.each(events, fn event ->
      case event do
        {:mention, mention} ->
          Embot.NotificationHandler.process_mention(mention, mastodon) |> maybe_log_error()
      end
    end)

    {:noreply, [], mastodon}
  end

  defp maybe_log_error(result) do
    case result do
      :ok -> :ok
      {:error, reason} -> Logger.error(reason)
    end
  end

  # This replaces default log like this:
  # [notice] GenStage consumer #PID<0.1223.0> is stopping after receiving cancel from producer #PID<0.1214.0> with reason: ...
  @impl GenStage
  def handle_cancel({:down, {:shutdown, reason}}, _from, state) do
    case reason do
      reason
      when reason in [:transport_closed, :transport_done, :transport_timeout, :pool_done] ->
        Logger.info("stopping consumer", reason: reason)

      reason ->
        Logger.warning("stopping consumer", reason: reason)
    end

    {:noreply, [], state}
  end
end
