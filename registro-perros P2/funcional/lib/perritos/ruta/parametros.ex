defmodule Perritos.Ruta.Parametros do
  @moduledoc """
  NÚCLEO. Convierte los parámetros de la petición (un mapa de textos, como
  llegan en el query string) en datos para `Perritos.Ruta.planear/3`.

  Es puro: recibe un mapa y regresa una tupla. El router sólo se lo pasa.
  """

  @doc """
  Lee `lat`, `lon` (obligatorios), `radio` y `max` (opcionales).

      iex> Perritos.Ruta.Parametros.leer(%{"lat" => "25.42", "lon" => "-101.0", "radio" => "800"})
      {:ok, {25.42, -101.0}, [radio: 800, max: nil]}

      iex> Perritos.Ruta.Parametros.leer(%{"lat" => "abc", "lon" => "-101"})
      {:error, "lat debe ser un número"}
  """
  # ✅ REQ 6 · COMPOSICIÓN: with encadena las validaciones
  def leer(params) do
    with {:ok, lat} <- numero(params["lat"], "lat"),
         {:ok, lon} <- numero(params["lon"], "lon"),
         :ok <- en_rango(lat, -90, 90, "lat"),
         :ok <- en_rango(lon, -180, 180, "lon"),
         {:ok, radio} <- entero(params["radio"], "radio", 2_000),
         {:ok, max} <- entero(params["max"], "max", nil) do
      {:ok, {lat, lon}, [radio: radio, max: max]}
    end
  end

  # ✅ REQ 3 · PATTERN MATCHING: falta / vacío / texto
  defp numero(nil, nombre), do: {:error, "falta #{nombre}"}

  defp numero(texto, nombre) do
    case Float.parse(texto) do
      {valor, ""} -> {:ok, valor}
      _ -> {:error, "#{nombre} debe ser un número"}
    end
  end

  defp en_rango(valor, min, max, _nombre) when valor >= min and valor <= max, do: :ok
  defp en_rango(_valor, min, max, nombre), do: {:error, "#{nombre} debe estar entre #{min} y #{max}"}

  defp entero(nil, _nombre, omision), do: {:ok, omision}
  defp entero("", _nombre, omision), do: {:ok, omision}

  defp entero(texto, nombre, _omision) do
    case Integer.parse(texto) do
      {valor, ""} when valor > 0 -> {:ok, valor}
      _ -> {:error, "#{nombre} debe ser un entero positivo"}
    end
  end
end
