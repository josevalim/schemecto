defmodule Schemecto.MixProject do
  use Mix.Project

  def project do
    [
      app: :schemecto,
      version: "0.1.0",
      elixir: "~> 1.20-rc",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: if(Mix.env() == :test, do: ["lib", "test/support"], else: ["lib"]),
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [{:ecto, "~> 3.12"}]
  end
end
