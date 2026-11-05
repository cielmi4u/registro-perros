defmodule Perritos.Ruta do
  @moduledoc """
  NÚCLEO de la funcionalidad 6, **ruta de rescate**.

  Dado un punto de partida y los perros registrados, se queda con los que
  están dentro de una zona (un radio en metros alrededor del inicio) y
  propone en qué orden visitarlos con la heurística del **vecino más
  cercano**: ir al perro más cercano, quitarlo de la lista y repetir desde
  ahí con los que quedan. También calcula la distancia de cada tramo y la
  total.

  Todas las funciones son puras: no consultan el backend, no leen el reloj,
  no imprimen. Los perros llegan como argumento y el resultado sale como dato.
  """

  # ✅ REQ 1 · NÚCLEO PURO: este módulo no consulta el backend, no recibe conn,
  #   no lee el reloj y no imprime. Datos entran, datos salen.
  # ✅ REQ 2 · CERO ESTADO MUTABLE: sin Agent/GenServer/ETS ni Enum.each; todo viaja como argumento.
  # ✅ REQ 8 · @doc con ejemplos iex> (doctests) en cada función pública.
  alias Perritos.Geo

  @radio_omision 2_000

  # ---------------------------------------------------------------
  # Funciones que REGRESAN funciones (orden superior)
  # ---------------------------------------------------------------

  @doc """
  Regresa una **función** que mide qué tan lejos está un perro de `origen`.

      iex> desde_alameda = Perritos.Ruta.distancia_desde({25.4232, -101.0053})
      iex> desde_alameda.(%{lat: 25.4232, lon: -101.0053})
      0.0
  """
  # ✅ REQ 4 · ORDEN SUPERIOR: esta función REGRESA una función (fn perro -> metros)
  def distancia_desde(origen) do
    fn perro -> Geo.distancia(origen, Geo.punto(perro)) end
  end

  @doc """
  Regresa una **función filtro**: `true` si el perro está a `radio` metros
  o menos de `centro`. El borde cuenta como dentro.

      iex> dentro? = Perritos.Ruta.en_zona({0.0, 0.0}, 1_000)
      iex> dentro?.(%{lat: 0.0, lon: 0.005})
      true
      iex> dentro?.(%{lat: 0.0, lon: 0.05})
      false
  """
  # ✅ REQ 4 · ORDEN SUPERIOR: REGRESA una función filtro
  def en_zona(centro, radio) do
    distancia = distancia_desde(centro)
    fn perro -> distancia.(perro) <= radio end
  end

  # ---------------------------------------------------------------
  # Pattern matching con cláusulas múltiples
  # ---------------------------------------------------------------

  @doc """
  ¿El perro trae coordenadas utilizables?

      iex> Perritos.Ruta.con_ubicacion?(%{lat: 25.4, lon: -101.0})
      true
      iex> Perritos.Ruta.con_ubicacion?(%{lat: nil, lon: -101.0})
      false
  """
  # ✅ REQ 3 · PATTERN MATCHING: dos cláusulas en vez de if
  def con_ubicacion?(%{lat: lat, lon: lon}) when is_number(lat) and is_number(lon), do: true
  def con_ubicacion?(_perro), do: false

  # ---------------------------------------------------------------
  # Función que RECIBE una función
  # ---------------------------------------------------------------

  @doc """
  **Recibe una función** `medir` (perro → número) y regresa el perro con el
  valor más chico. En un empate gana el de `id` menor, para que el
  resultado sea siempre el mismo. Con la lista vacía regresa `nil`.

      iex> perros = [%{id: 1, d: 30}, %{id: 2, d: 10}, %{id: 3, d: 10}]
      iex> Perritos.Ruta.mas_cercano(perros, & &1.d)
      %{id: 2, d: 10}
      iex> Perritos.Ruta.mas_cercano([], & &1.d)
      nil
  """
  # ✅ REQ 4 · ORDEN SUPERIOR: esta función RECIBE una función (medir)
  def mas_cercano(perros, medir) when is_function(medir, 1) do
    Enum.min_by(perros, fn perro -> {medir.(perro), perro.id} end, fn -> nil end)
  end

  # ---------------------------------------------------------------
  # Recursión explícita: vecino más cercano
  # ---------------------------------------------------------------

  @doc """
  Ordena los perros con la heurística del vecino más cercano, partiendo de
  `origen`. Es **recursiva**: toma el más cercano, lo quita de la lista y
  repite desde la posición de ese perro con los que quedan.

      iex> a = %{id: 1, lat: 0.0, lon: 0.003}
      iex> b = %{id: 2, lat: 0.0, lon: 0.001}
      iex> c = %{id: 3, lat: 0.0, lon: 0.002}
      iex> Perritos.Ruta.orden_de_visita({0.0, 0.0}, [a, b, c]) |> Enum.map(& &1.id)
      [2, 3, 1]
  """
  def orden_de_visita(origen, perros), do: visitar(origen, perros, [])

  # ✅ REQ 5 · RECURSIÓN EXPLÍCITA (vecino más cercano)
  # ✅ REQ 3 · cláusula 1 = caso base (ya no quedan perros), cláusula 2 = paso recursivo
  defp visitar(_actual, [], visitados), do: Enum.reverse(visitados)

  defp visitar(actual, pendientes, visitados) do
    siguiente = mas_cercano(pendientes, distancia_desde(actual))
    # ↓ llamada recursiva: desde el perro elegido, con los que quedan
    visitar(Geo.punto(siguiente), List.delete(pendientes, siguiente), [siguiente | visitados])
  end

  # ---------------------------------------------------------------
  # Tramos y distancia total (Stream)
  # ---------------------------------------------------------------

  @doc """
  Para una ruta ya ordenada, calcula cada parada con la distancia desde la
  parada anterior (`tramo`) y la acumulada, ambas en metros redondeados.

  Usa `Stream`: los pares de puntos consecutivos, sus distancias y la suma
  acumulada se describen como flujos perezosos y sólo se calculan una vez,
  al armar la lista final, sin listas intermedias.

      iex> ruta = [%{id: 1, lat: 0.0, lon: 0.001}, %{id: 2, lat: 0.0, lon: 0.002}]
      iex> Perritos.Ruta.tramos({0.0, 0.0}, ruta) |> Enum.map(&{&1.tramo, &1.acumulada})
      [{111, 111}, {111, 222}]
  """
  # ✅ STREAM (requisito de equipo): pares, distancias y acumulado como flujos perezosos
  # ✅ REQ 6 · COMPOSICIÓN con |>
  def tramos(origen, ruta) do
    distancias =
      [origen | Enum.map(ruta, &Geo.punto/1)]
      |> Stream.chunk_every(2, 1, :discard)
      |> Stream.map(fn [a, b] -> Geo.distancia(a, b) end)

    acumuladas = Stream.scan(distancias, &+/2)

    [ruta, distancias, acumuladas]
    |> Stream.zip()
    |> Stream.with_index(1)
    |> Enum.map(fn {{perro, tramo, acumulada}, orden} ->
      %{orden: orden, perro: perro, tramo: round(tramo), acumulada: round(acumulada)}
    end)
  end

  @doc """
  Distancia total, en metros, de una lista de paradas hecha por `tramos/2`.

      iex> Perritos.Ruta.distancia_total([])
      0
      iex> Perritos.Ruta.distancia_total([%{acumulada: 111}, %{acumulada: 222}])
      222
  """
  # ✅ REQ 3 · PATTERN MATCHING: lista vacía vs. con paradas
  def distancia_total([]), do: 0
  def distancia_total(paradas), do: paradas |> List.last() |> Map.fetch!(:acumulada)

  # ---------------------------------------------------------------
  # La función principal: el flujo completo con |>
  # ---------------------------------------------------------------

  @doc """
  Planea la ruta de rescate.

  Opciones:

    * `:radio` — metros alrededor de `origen` que forman la zona (por omisión 2000).
    * `:max` — si se da, sólo los `max` perros más cercanos al inicio.

  Los perros sin coordenadas se ignoran.

      iex> perros = [
      ...>   %{id: 1, lat: 0.0, lon: 0.002},
      ...>   %{id: 2, lat: 0.0, lon: 0.001},
      ...>   %{id: 3, lat: 5.0, lon: 5.0},
      ...>   %{id: 4, lat: nil, lon: nil}
      ...> ]
      iex> plan = Perritos.Ruta.planear({0.0, 0.0}, perros, radio: 500)
      iex> {Enum.map(plan.paradas, & &1.perro.id), plan.distancia_total}
      {[2, 1], 222}
  """
  # ✅ REQ 6 · COMPOSICIÓN con |>: filtrar → zona → limitar → ordenar → tramos
  def planear(origen, perros, opciones \\ []) do
    radio = Keyword.get(opciones, :radio, @radio_omision)

    paradas =
      perros
      |> Enum.filter(&con_ubicacion?/1)
      |> Enum.filter(en_zona(origen, radio))
      |> limitar(origen, Keyword.get(opciones, :max))
      |> then(&orden_de_visita(origen, &1))
      |> then(&tramos(origen, &1))

    %{
      inicio: origen,
      radio: radio,
      paradas: paradas,
      total_perros: length(paradas),
      distancia_total: distancia_total(paradas)
    }
  end

  # ✅ REQ 3 · PATTERN MATCHING: sin máximo (nil) vs. con máximo
  defp limitar(perros, _origen, nil), do: perros

  defp limitar(perros, origen, max) when is_integer(max) and max > 0 do
    medir = distancia_desde(origen)

    perros
    |> Enum.sort_by(&{medir.(&1), &1.id})
    |> Enum.take(max)
  end
end
