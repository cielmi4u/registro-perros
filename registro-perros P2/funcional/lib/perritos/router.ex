defmodule Perritos.Router do
  @moduledoc """
  CÁSCARA HTTP. Cada ruta hace siempre lo mismo:
  leer la petición → traer los datos → llamar al núcleo → responder JSON.
  Aquí no se calcula nada.

  Las rutas llevan el prefijo `/f` porque nginx lo conserva.
  """
  # ⚙️ CÁSCARA (no es núcleo): aquí SÍ hay efectos: HTTP, reloj, red. Cada ruta:
  #   leer petición → traer datos (Datos) → llamar al núcleo → responder JSON.
  use Plug.Router

  alias Perritos.{Datos, Estadisticas, Ruta}
  alias Perritos.Ruta.Parametros

  plug :match
  plug :dispatch

  get "/f/salud" do
    send_resp(conn, 200, "ok")
  end

  # ---------- Funcionalidad 6: ruta de rescate ----------
  # GET /f/ruta?lat=25.4232&lon=-101.0053&radio=1500&max=10
  get "/f/ruta" do
    conn = fetch_query_params(conn)

    with {:ok, origen, opciones} <- Parametros.leer(conn.query_params),
         {:datos, {:ok, perros}} <- {:datos, Datos.avistamientos()} do
      plan = Ruta.planear(origen, perros, opciones)
      responder_json(conn, 200, plan_a_json(plan))
    else
      {:error, mensaje} when is_binary(mensaje) ->
        responder_json(conn, 400, %{error: mensaje})

      {:datos, {:error, _motivo}} ->
        responder_json(conn, 503, %{error: "el backend del P1 no respondió"})
    end
  end

  # ---------- Funcionalidad 3: estadísticas ----------
  # GET /f/estadisticas?n=5&dias=30
  get "/f/estadisticas" do
    conn = fetch_query_params(conn)
    # efecto: leer el reloj (TZ=America/Monterrey en el compose)
    hoy = NaiveDateTime.local_now() |> NaiveDateTime.to_date()

    with {:ok, opciones} <- Estadisticas.Parametros.leer(conn.query_params),
         {:datos, {:ok, perros}} <- {:datos, Datos.avistamientos()} do
      responder_json(conn, 200, Estadisticas.resumen(perros, hoy, opciones))
    else
      {:error, mensaje} when is_binary(mensaje) ->
        responder_json(conn, 400, %{error: mensaje})

      {:datos, {:error, _motivo}} ->
        responder_json(conn, 503, %{error: "el backend del P1 no respondió"})
    end
  end

  match _ do
    send_resp(conn, 404, "no encontrado")
  end

  # Las tuplas no existen en JSON: el punto {lat, lon} se vuelve mapa aquí,
  # justo antes de responder. El núcleo sigue usando tuplas.
  defp plan_a_json(%{inicio: {lat, lon}} = plan), do: %{plan | inicio: %{lat: lat, lon: lon}}

  defp responder_json(conn, status, datos) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(datos))
  end
end
