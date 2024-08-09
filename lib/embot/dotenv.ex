defmodule Embot.Dotenv do
  def read(path) do
    case File.read(path) do
      {:ok, content} -> decode(content)
      {:error, :enoent} -> %{}
    end
  end

  defp decode(content) do
    String.split(content, "\n") |> Stream.map(&decode_line/1) |> Map.new()
  end

  defp decode_line(""), do: {nil, nil}

  defp decode_line(line) do
    [key, value] = String.split(line, "=") |> Enum.map(&String.trim/1)
    {key, value}
  end
end
