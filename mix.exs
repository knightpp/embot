defmodule Embot.MixProject do
  use Mix.Project

  def project do
    [
      app: :embot,
      version: "0.1.1",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test,
        "coveralls.json": :test,
        release: :prod
      ]
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
      {:nimble_parsec, "~> 1.4"},
      {:observer_cli, "~> 1.7"},
      {:plug, "~> 1.16", only: [:test]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:bandit, "~> 1.5", only: [:test]},
      {:thousand_island, "~> 1.3", only: [:test]},
      {:bypass, "~> 2.1", only: [:test]},
      {:benchee, "~> 1.0", only: [:test, :dev]}
    ]
  end
end
