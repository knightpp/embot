defmodule Embot.Sse do
  def parse(event) do
    event
    |> String.splitter("\n", trim: true)
    |> Stream.map(&parse_line/1)
  end

  @spec accumulate([String.t()], String.t()) :: {:more, [String.t()]} | {:done, String.t()}
  def accumulate(acc, data) do
    case :binary.split(data, "\n\n") do
      [part] -> {:more, [part | acc]}
      [part, ""] -> {:done, IO.iodata_to_binary(:lists.reverse(acc, part))}
    end
  end

  defp parse_line(line) do
    line |> :binary.split(":") |> parse_line_from_parts()
  end

  defp parse_line_from_parts([_]) do
    {:error, :no_semicolon}
  end

  defp parse_line_from_parts([key, value]) do
    value = String.trim_leading(value)

    case key do
      "" -> {:ok, {:comment, value}}
      "event" -> {:ok, {:event, value}}
      "data" -> decode(value)
      "id" -> {:ok, {:id, value}}
      "retry" -> {:ok, {:retry, value}}
      _ -> {:error, :unknown_key}
    end
  end

  defp decode(value) do
    with {:ok, data} <- Jason.decode(value) do
      {:ok, {:data, data}}
    end
  end
end
