defmodule Embot.Command do
  import NimbleParsec

  def parse(text) do
    case command(text) do
      {:ok, arg, _, _, _, _} -> arg
      {:error, _, _, _, _, _} -> []
    end
  end

  prefix = ignore(string("-"))
  cw = string("cw") |> replace(:cw)

  arg =
    ignore(string(~s/="/))
    |> utf8_string([not: ?"], min: 1, max: 255)
    |> ignore(string(~s/"/))

  cmd = prefix |> concat(cw) |> optional(arg) |> reduce({:group, []})

  defparsec(:command, eventually(cmd), inline: true)

  defp group([key]), do: {key, nil}
  defp group([key, value]), do: {key, value}
end
