defmodule Embot.Streaming.Sse do
  def collector(on_data) when is_function(on_data) do
    fn {:data, data}, state ->
      on_data.(data)
      {:cont, state}
    end
  end

  def collector(on_data) when is_atom(on_data) do
    fn {:data, data}, state ->
      apply(on_data, :handle_data, [data])
      {:cont, state}
    end
  end

  def parse(data) do
    String.splitter(data, "\n")
    |> Stream.filter(fn line -> line != "" end)
    |> Enum.map(&parse_line/1)
  end

  defp parse_line(line) do
    [key, value] = :binary.split(line, ":")

    case key do
      "" -> {:comment, value}
      "event" -> {:event, value}
      "data" -> {:data, value}
    end
  end
end
