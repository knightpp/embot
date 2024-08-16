defmodule Embot.Sse do
  require Logger

  def parse(data) do
    String.splitter(data, "\n\n")
    |> Stream.flat_map(fn event ->
      String.splitter(event, "\n", trim: true)
      |> Stream.map(&parse_line/1)
      |> Stream.filter(fn
        {:ok, _data} ->
          true

        {:error, error} ->
          dbg(data)
          Logger.error("could not parse sse line", error: inspect(error))
          false
      end)
      |> Stream.map(fn {:ok, data} -> data end)
    end)
  end

  defp parse_line(line) do
    line |> :binary.split(":") |> parse_line_from_parts()
  end

  defp parse_line_from_parts([_]) do
    {:error, :no_semicolon}
  end

  defp parse_line_from_parts([key, value]) do
    case key do
      "" -> {:ok, {:comment, value}}
      "event" -> {:ok, {:event, String.trim(value)}}
      "data" -> decode(value)
      _ -> {:error, :unknown_key}
    end
  end

  defp decode(value) do
    with {:ok, data} <- Jason.decode(value) do
      {:ok, {:data, data}}
    end
  end
end
