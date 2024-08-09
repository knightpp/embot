defmodule Embot.Database do
  def get(path) do
    with {:ok, content} <- File.read(path) do
      {:ok, :erlang.binary_to_term(content)}
    end
  end

  def put(path, value) do
    File.write!(path, :erlang.term_to_binary(value))
  end
end
