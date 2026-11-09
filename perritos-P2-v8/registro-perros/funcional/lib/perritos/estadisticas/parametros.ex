defmodule Perritos.Estadisticas.Parametros do
  @moduledoc """
  NÚCLEO. Convierte el query string de `/f/estadisticas` (textos) en las
  opciones de `Perritos.Estadisticas.resumen/3`. Puro: mapa entra, tupla sale.
  """

  @doc """
  Lee `n` (1 a 20, por omisión 5) y `dias` (1 a 365, por omisión 30).

      iex> Perritos.Estadisticas.Parametros.leer(%{"n" => "8"})
      {:ok, [n: 8, dias: 30]}

      iex> Perritos.Estadisticas.Parametros.leer(%{"dias" => "mil"})
      {:error, "dias debe ser un entero entre 1 y 365"}
  """
  # ✅ REQ 6 · COMPOSICIÓN: with encadena las validaciones
  def leer(params) do
    with {:ok, n} <- entero(params["n"], "n", 5, {1, 20}),
         {:ok, dias} <- entero(params["dias"], "dias", 30, {1, 365}) do
      {:ok, [n: n, dias: dias]}
    end
  end

  # ✅ REQ 3 · PATTERN MATCHING: falta / vacío / texto
  defp entero(nil, _nombre, omision, _rango), do: {:ok, omision}
  defp entero("", _nombre, omision, _rango), do: {:ok, omision}

  defp entero(texto, nombre, _omision, {min, max}) do
    case Integer.parse(texto) do
      {valor, ""} when valor >= min and valor <= max -> {:ok, valor}
      _ -> {:error, "#{nombre} debe ser un entero entre #{min} y #{max}"}
    end
  end
end
