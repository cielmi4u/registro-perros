defmodule Perritos.Avistamiento do
  @moduledoc """
  Un avistamiento de perro, tal como lo usa el núcleo. Sólo datos.

  Los colores son textos tal como vienen del catálogo del P1
  (por ejemplo `"Negro"`, `"Manchado (blanco y negro)"`), por eso no
  se convierten a átomos. `lat`/`lon` pueden ser `nil` si el perro se
  registró sin GPS.
  """

  @derive {Jason.Encoder, only: [:id, :nombre, :raza, :colores, :calle, :lat, :lon, :foto, :fecha]}
  defstruct [:id, :nombre, :raza, :calle, :lat, :lon, :foto, :fecha, colores: []]
end
