defmodule Embot.Sse do
  def parse!(data) do
    String.splitter(data, "\n")
    |> Stream.filter(fn line -> line != "" end)
    |> Enum.map(&parse_line!/1)
  end

  defp parse_line!(line) do
    [key, value] = :binary.split(line, ":")

    case key do
      "" ->
        {:comment, value}

      "event" ->
        {:event, String.trim(value)}

      "data" ->
        dbg(value)
        {:data, Jason.decode!(value)}
    end
  end
end
