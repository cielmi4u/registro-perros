defmodule Perritos.Datos do
  @moduledoc """
  CÁSCARA. Trae los perros del backend Java del P1 (opción B) por HTTP
  y los convierte en structs `Perritos.Avistamiento` para el núcleo.

  El backend expone `GET /api/perros`, que regresa un arreglo JSON como:

      {"id":1,"nombre":"Firulais","raza":"","colorPrincipal":"Negro",
       "colorSecundario":"Blanco","colorTerciario":"","calle":"Allende",
       "entreCalle1":"","entreCalle2":"","fecha":"2026-09-27",
       "lat":25.4232,"lng":-101.0053,"foto":"/fotos/perro_1.jpg"}

  El backend manda `""` en lugar de `null` para los textos vacíos; aquí
  se convierten a `nil` para que el núcleo use pattern matching normal.
  """

  # ⚙️ CÁSCARA (opción B): efecto de red, pide los perros al backend Java con Req.
  alias Perritos.Avistamiento
  require Logger

  def avistamientos do
    url = System.get_env("BACKEND_URL", "http://backend:8081") <> "/api/perros"

    case Req.get(url, retry: false, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: lista}} when is_list(lista) ->
        {:ok, Enum.map(lista, &a_avistamiento/1)}

      {:ok, %Req.Response{status: status, body: cuerpo}} ->
        # efecto: dejar en el log por qué falló (docker compose logs funcional)
        Logger.error("GET #{url} respondió #{status}: #{inspect(cuerpo)}")
        {:error, {:status, status}}

      {:error, error} ->
        Logger.error("GET #{url} falló: #{inspect(error)}")
        {:error, error}
    end
  end

  defp a_avistamiento(m) do
    %Avistamiento{
      id: m["id"],
      nombre: m["nombre"],
      raza: vacio_a_nil(m["raza"]),
      colores:
        [m["colorPrincipal"], m["colorSecundario"], m["colorTerciario"]]
        |> Enum.map(&vacio_a_nil/1)
        |> Enum.reject(&is_nil/1),
      calle: vacio_a_nil(m["calle"]),
      lat: m["lat"],
      lon: m["lng"],
      foto: m["foto"],
      fecha: fecha(m["fecha"])
    }
  end

  defp vacio_a_nil(nil), do: nil
  defp vacio_a_nil(""), do: nil
  defp vacio_a_nil(texto), do: texto

  defp fecha(texto) when is_binary(texto) do
    case Date.from_iso8601(texto) do
      {:ok, fecha} -> fecha
      {:error, _} -> nil
    end
  end

  defp fecha(_), do: nil
end
