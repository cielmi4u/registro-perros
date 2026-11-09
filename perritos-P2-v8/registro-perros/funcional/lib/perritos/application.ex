defmodule Perritos.Application do
  @moduledoc "CÁSCARA. Arranca el servidor HTTP (Bandit) con el router."
  use Application

  @impl true
  def start(_tipo, _args) do
    puerto = String.to_integer(System.get_env("PUERTO", "4000"))

    hijos = [
      # Opción B: no hay conexión a base de datos que arrancar, Req no la necesita
      {Bandit, plug: Perritos.Router, port: puerto}
    ]

    Supervisor.start_link(hijos, strategy: :one_for_one, name: Perritos.Supervisor)
  end
end
