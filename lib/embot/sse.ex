defmodule Embot.Sse do
  @spec parse(String.t()) :: Enumerable.t()
  def parse(event) do
    event
    |> String.splitter("\n", trim: true)
    |> Stream.map(&parse_line/1)
  end

  @spec accumulate(acc :: [String.t()], data :: String.t()) ::
          {ready :: [String.t()], acc :: [String.t()]}
  def accumulate(acc, data)
  def accumulate([], data), do: data |> split()
  def accumulate([acc], data), do: (acc <> data) |> split()

  @spec split(String.t()) :: {[String.t()], [String.t()]}
  defp split(data) do
    data
    |> String.split("\n\n")
    |> Enum.split(-1)
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
