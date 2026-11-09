defmodule Perritos.Geo do
  @moduledoc """
  NÚCLEO. Geometría sobre la Tierra: distancias en metros con haversine.

  Un punto es una tupla `{lat, lon}` en grados. Funciones puras: no
  dependen de nada de afuera.
  """

  @radio_tierra 6_371_000

  @doc """
  Distancia en metros entre dos puntos `{lat, lon}` (fórmula de haversine).

      iex> Perritos.Geo.distancia({25.4232, -101.0053}, {25.4232, -101.0053})
      0.0

      iex> Perritos.Geo.distancia({0.0, 0.0}, {0.0, 1.0}) |> round()
      111195
  """
  def distancia({lat1, lon1}, {lat2, lon2}) do
    {f1, f2} = {radianes(lat1), radianes(lat2)}
    df = radianes(lat2 - lat1)
    dl = radianes(lon2 - lon1)

    a =
      :math.pow(:math.sin(df / 2), 2) +
        :math.cos(f1) * :math.cos(f2) * :math.pow(:math.sin(dl / 2), 2)

    2 * @radio_tierra * :math.asin(:math.sqrt(min(a, 1.0)))
  end

  @doc """
  Extrae el punto `{lat, lon}` de cualquier mapa o struct con `:lat` y `:lon`.

      iex> Perritos.Geo.punto(%{lat: 25.42, lon: -101.0})
      {25.42, -101.0}
  """
  def punto(%{lat: lat, lon: lon}), do: {lat, lon}

  defp radianes(grados), do: grados * :math.pi() / 180
end
