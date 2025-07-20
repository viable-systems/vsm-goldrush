defmodule VsmGoldrush.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_org "viable-systems"
  @description "VSM-aware wrapper for goldrush event processing with cybernetic failure detection"

  def project do
    [
      app: :vsm_goldrush,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      package: package(),
      description: @description,
      source_url: "https://github.com/#{@github_org}/vsm-goldrush",
      homepage_url: "https://github.com/#{@github_org}/vsm-goldrush",
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {VsmGoldrush.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core dependency - goldrush is what we're wrapping!
      {:goldrush, "~> 0.1.9"},
      
      # Optional GenStage for streaming integration
      {:gen_stage, "~> 1.2"},
      
      # Runtime introspection and monitoring
      {:telemetry, "~> 1.2"},
      
      # Development & Testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:benchee, "~> 1.3", only: :dev}
    ]
  end
  
  defp package do
    [
      organization: "viable_systems",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/#{@github_org}/vsm-goldrush"
      },
      maintainers: ["Viable Systems Team"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        "Core API": [~r/^VsmGoldrush$/],
        "Query Building": [~r/QueryBuilder/],
        "Event Processing": [~r/EventProcessor/],
        "Pattern Library": [~r/Patterns/]
      ]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "compile"],
      test: ["test"],
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": ["format --check-formatted", "credo --strict", "dialyzer"]
    ]
  end
end
