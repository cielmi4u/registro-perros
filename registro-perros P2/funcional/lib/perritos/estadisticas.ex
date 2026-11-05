defmodule Perritos.Estadisticas do
  @moduledoc """
  NÚCLEO de la funcionalidad 3, **estadísticas**.

  Cuenta avistamientos por color, por raza y por día, y saca los `n` más
  comunes. No hay contadores que cambien: todo se cuenta con `Enum.reduce`
  sobre un mapa que se va regresando nuevo en cada paso.

  Todas las funciones reciben cualquier `Enumerable`: sirven igual sobre una
  **lista** que sobre un **Stream** (ver la prueba "lista y Stream dan lo mismo").

  Son puras: no consultan el backend y no leen el reloj; el día de "hoy"
  llega como argumento desde la cáscara.
  """

  # ✅ REQ 1 · NÚCLEO PURO: no consulta el backend, no lee el reloj ("hoy" llega
  #   como argumento), no imprime. Datos entran, datos salen.
  # ✅ REQ 2 · CERO ESTADO MUTABLE: no hay contadores; se cuenta con Enum.reduce.
  # ✅ REQ 8 · @doc con ejemplos iex> (doctests) en cada función pública.
  @sin_raza "Sin raza"

  # ---------------------------------------------------------------
  # Funciones que REGRESAN funciones
  # ---------------------------------------------------------------

  @doc """
  Regresa una **función** que, dado un perro, da la lista de claves bajo las
  que se cuenta: sus colores, su raza o su día.

  Es lista porque un perro puede tener hasta tres colores (cuenta una vez
  en cada uno) y un perro sin fecha no cuenta en ningún día.

      iex> perro = %{colores: ["Negro", "Blanco", "Negro"], raza: nil, fecha: ~D[2026-11-01]}
      iex> Perritos.Estadisticas.extractor(:color).(perro)
      ["Negro", "Blanco"]
      iex> Perritos.Estadisticas.extractor(:raza).(perro)
      ["Sin raza"]
      iex> Perritos.Estadisticas.extractor(:dia).(perro)
      [~D[2026-11-01]]
  """
  # ✅ REQ 4 · ORDEN SUPERIOR: extractor/1 REGRESA una función
  # ✅ REQ 3 · PATTERN MATCHING: una cláusula por átomo (:color, :raza, :dia)
  def extractor(:color), do: fn perro -> Enum.uniq(perro.colores) end
  def extractor(:raza), do: fn perro -> [etiqueta_raza(perro.raza)] end
  def extractor(:dia), do: fn perro -> dia(perro.fecha) end

  @doc """
  Regresa una **función filtro**: `true` si el perro se vio entre `desde`
  y `hasta`, ambos días incluidos.

      iex> en_octubre = Perritos.Estadisticas.en_periodo(~D[2026-10-01], ~D[2026-10-31])
      iex> en_octubre.(%{fecha: ~D[2026-10-31]})
      true
      iex> en_octubre.(%{fecha: ~D[2026-11-01]})
      false
      iex> en_octubre.(%{fecha: nil})
      false
  """
  # ✅ REQ 4 · ORDEN SUPERIOR: REGRESA una función filtro
  def en_periodo(desde, hasta) do
    fn perro -> dentro?(dia(perro.fecha), desde, hasta) end
  end

  # ---------------------------------------------------------------
  # Pattern matching con cláusulas múltiples
  # ---------------------------------------------------------------

  @doc """
  Nombre con el que se cuenta una raza; vacía o `nil` es "Sin raza".

      iex> Perritos.Estadisticas.etiqueta_raza(nil)
      "Sin raza"
      iex> Perritos.Estadisticas.etiqueta_raza("Labrador")
      "Labrador"
  """
  # ✅ REQ 3 · PATTERN MATCHING: nil, "" y cualquier otra raza
  def etiqueta_raza(nil), do: @sin_raza
  def etiqueta_raza(""), do: @sin_raza
  def etiqueta_raza(raza), do: raza

  # ✅ REQ 3 · PATTERN MATCHING: sin fecha, Date o NaiveDateTime
  defp dia(nil), do: []
  defp dia(%Date{} = fecha), do: [fecha]
  defp dia(%NaiveDateTime{} = fecha), do: [NaiveDateTime.to_date(fecha)]

  defp dentro?([], _desde, _hasta), do: false

  defp dentro?([fecha], desde, hasta) do
    Date.compare(fecha, desde) != :lt and Date.compare(fecha, hasta) != :gt
  end

  # ---------------------------------------------------------------
  # Función que RECIBE una función: contar con reduce
  # ---------------------------------------------------------------

  @doc """
  **Recibe una función** `extraer` (perro → lista de claves) y cuenta cuántas
  veces sale cada clave. Regresa un mapa `%{clave => total}`.

  No hay contador: `Enum.reduce` parte de `%{}` y en cada paso regresa un
  mapa nuevo con la clave aumentada. Acepta una lista o un Stream.

      iex> perros = [%{colores: ["Negro"]}, %{colores: ["Negro", "Blanco"]}]
      iex> Perritos.Estadisticas.contar(perros, & &1.colores)
      %{"Blanco" => 1, "Negro" => 2}
      iex> Perritos.Estadisticas.contar([], & &1.colores)
      %{}
  """
  # ✅ REQ 4 · ORDEN SUPERIOR: esta función RECIBE una función (extraer)
  # ✅ REQ 2 · Enum.reduce en vez de contador: cada paso regresa un mapa NUEVO
  # ✅ STREAM: Stream.flat_map; sirve igual con una lista o con un Stream
  def contar(avistamientos, extraer) when is_function(extraer, 1) do
    avistamientos
    |> Stream.flat_map(extraer)
    |> Enum.reduce(%{}, fn clave, conteos -> Map.update(conteos, clave, 1, &(&1 + 1)) end)
  end

  @doc """
  Los `n` más comunes de un mapa de conteos, de mayor a menor. En un empate
  van en orden alfabético, para que el resultado sea siempre el mismo.

      iex> Perritos.Estadisticas.mas_comunes(%{"Negro" => 4, "Gris" => 4, "Blanco" => 9}, 2)
      [%{etiqueta: "Blanco", total: 9}, %{etiqueta: "Gris", total: 4}]
  """
  # ✅ REQ 6 · COMPOSICIÓN con |>
  def mas_comunes(conteos, n) when is_integer(n) and n >= 0 do
    conteos
    |> Enum.sort_by(fn {etiqueta, total} -> {-total, etiqueta} end)
    |> Enum.take(n)
    |> Enum.map(fn {etiqueta, total} -> %{etiqueta: etiqueta, total: total} end)
  end

  # ---------------------------------------------------------------
  # Recursión explícita: la serie de días sin huecos
  # ---------------------------------------------------------------

  @doc """
  Convierte un mapa `%{fecha => total}` en una lista con **todos** los días
  de `desde` a `hasta`, poniendo 0 en los días sin avistamientos (para que
  la gráfica no se salte días).

  Es **recursiva**: arma el día actual y se llama con el día siguiente,
  hasta pasarse de `hasta`.

      iex> conteos = %{~D[2026-11-01] => 3, ~D[2026-11-03] => 1}
      iex> Perritos.Estadisticas.serie_diaria(conteos, ~D[2026-11-01], ~D[2026-11-03])
      [
        %{fecha: ~D[2026-11-01], total: 3},
        %{fecha: ~D[2026-11-02], total: 0},
        %{fecha: ~D[2026-11-03], total: 1}
      ]
  """
  def serie_diaria(conteos, desde, hasta) do
    rellenar(Date.compare(desde, hasta), desde, hasta, conteos)
  end

  # ✅ REQ 5 · RECURSIÓN EXPLÍCITA: arma un día y se llama con el siguiente
  # ✅ REQ 3 · cláusula :gt = caso base (ya se pasó del último día)
  defp rellenar(:gt, _dia, _hasta, _conteos), do: []

  defp rellenar(_no_se_ha_pasado, dia, hasta, conteos) do
    siguiente = Date.add(dia, 1)

    [
      %{fecha: dia, total: Map.get(conteos, dia, 0)}
      # ↓ llamada recursiva con el día siguiente
      | rellenar(Date.compare(siguiente, hasta), siguiente, hasta, conteos)
    ]
  end

  # ---------------------------------------------------------------
  # La función principal: el flujo completo con |>
  # ---------------------------------------------------------------

  @doc """
  Resumen de los últimos `dias` días que terminan en `hoy`.

  Opciones: `:n` (cuántos colores y razas, por omisión 5) y `:dias`
  (tamaño del periodo, por omisión 30).

  El periodo es un `Stream`: el filtro no crea una lista nueva, y cada
  conteo lo recorre en una sola pasada.

      iex> perros = [
      ...>   %{colores: ["Negro"], raza: nil, fecha: ~D[2026-11-05]},
      ...>   %{colores: ["Negro", "Blanco"], raza: "Labrador", fecha: ~D[2026-11-04]},
      ...>   %{colores: ["Gris"], raza: nil, fecha: ~D[2026-09-01]}
      ...> ]
      iex> r = Perritos.Estadisticas.resumen(perros, ~D[2026-11-05], n: 1, dias: 2)
      iex> {r.total, r.por_color, r.por_raza, Enum.map(r.por_dia, & &1.total)}
      {2, [%{etiqueta: "Negro", total: 2}], [%{etiqueta: "Labrador", total: 1}], [1, 1]}
  """
  # ✅ REQ 6 · COMPOSICIÓN con |>: periodo |> contar |> mas_comunes
  # ✅ STREAM: el periodo es un Stream.filter (no crea lista nueva)
  def resumen(avistamientos, hoy, opciones \\ []) do
    n = Keyword.get(opciones, :n, 5)
    dias = Keyword.get(opciones, :dias, 30)
    desde = Date.add(hoy, -(dias - 1))

    periodo = Stream.filter(avistamientos, en_periodo(desde, hoy))

    %{
      desde: desde,
      hasta: hoy,
      dias: dias,
      total: Enum.count(periodo),
      por_color: periodo |> contar(extractor(:color)) |> mas_comunes(n),
      por_raza: periodo |> contar(extractor(:raza)) |> mas_comunes(n),
      por_dia: periodo |> contar(extractor(:dia)) |> serie_diaria(desde, hoy)
    }
  end
end
