defmodule Schemecto.MixProject do
  use Mix.Project

  def project do
    [
      app: :schemecto,
      version: "0.1.0",
      elixir: "~> 1.20-rc",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [{:ecto, "~> 3.8"}]
  end
end
