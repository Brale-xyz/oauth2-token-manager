defmodule OAuth2TokenManager.MixProject do
  use Mix.Project

  def project do
    [
      app: :oauth2_token_manager,
      version: "0.1.0",
      elixir: "~> 1.15",
      description: description(),
      package: package(),
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
      {:oauth2, "~> 2.1.0"},
      {:typed_struct, "~> 0.3.0"},
      {:jason, "~> 1.4.1"},
      {:mock, "~> 0.3.8", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    This package works with the `oauth2` package to manage the automatic renewal of tokens before they expire.
    """
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/Brale-xyz/oauth2-token-manager"}
    ]
  end
end
