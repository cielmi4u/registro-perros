defmodule Perritos.MixProject do
  use Mix.Project

  def project do
    [
      app: :funcional,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # las pruebas sólo prueban el núcleo: no arrancan la aplicación
      aliases: [test: "test --no-start"]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Perritos.Application, []}
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.16"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"},
      # Opción B: los datos llegan del backend Java del P1 (Oracle no tiene driver en la lista)
      {:req, "~> 0.5"}
    ]
  end
end
