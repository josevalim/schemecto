defmodule Schemecto.MixProject do
  use Mix.Project

  @version "0.1.0"
  @repo_url "https://github.com/josevalim/schemecto"
  def project do
    [
      app: :schemecto,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: if(Mix.env() == :test, do: ["lib", "test/support"], else: ["lib"]),
      deps: deps(),

      # Hex
      package: package(),
      description: "Schemaless Ecto changesets with support for nesting and JSON Schemas",

      # Docs
      name: "Schemecto",
      docs: &docs/0
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ecto, "~> 3.7"},
      {:ex_doc, "~> 0.34", only: :docs}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @repo_url,
        "Changelog" => "#{@repo_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @repo_url
    ]
  end
end
