defmodule OAuth2TokenManager.MixProject do
  use Mix.Project

  def project do
    [
      aliases: aliases(),
      app: :oauth2_token_manager,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:oauth2, "== 2.1.0"},
      {:typed_struct, "== 0.3.0"},
      {:jason, "== 1.4.1"},
      {:mock, "== 0.3.8", only: :test}
    ]
  end

  defp aliases do
    [
      setup: []
    ]
  end
end
