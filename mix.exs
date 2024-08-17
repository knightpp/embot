defmodule Embot.MixProject do
  use Mix.Project

  def project do
    [
      app: :embot,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Embot.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:gen_stage, "~> 1.2"},
      {:floki, "~> 0.36"},
      # optimized HTML parser
      {:html5ever, "~> 0.16"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
