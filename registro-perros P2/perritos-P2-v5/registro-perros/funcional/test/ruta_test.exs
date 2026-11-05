defmodule Perritos.RutaTest do
  # ✅ REQ 7 · PRUEBAS ExUnit del núcleo, sin servidor ni base de datos.
  # ✅ REQ 8 · doctest: corre como prueba cada ejemplo iex> de los @doc
  use ExUnit.Case, async: true

  doctest Perritos.Geo
  doctest Perritos.Ruta
  doctest Perritos.Ruta.Parametros

  alias Perritos.{Avistamiento, Geo, Ruta}
  alias Perritos.Ruta.Parametros

  # La Alameda Zaragoza, Saltillo
  @alameda {25.4232, -101.0053}

  defp perro(id, nombre, lat, lon, raza \\ nil) do
    %Avistamiento{id: id, nombre: nombre, lat: lat, lon: lon, raza: raza, colores: ["Negro"]}
  end

  describe "planear/3" do
    # ✅ REQ 7 · CASO BORDE
    test "sin perros regresa una ruta vacía con distancia 0" do
      plan = Ruta.planear(@alameda, [], radio: 1_000)

      assert plan.paradas == []
      assert plan.total_perros == 0
      assert plan.distancia_total == 0
    end

    # ✅ REQ 7 · CASO BORDE
    test "ningún perro dentro del radio da una ruta vacía" do
      lejos = perro(1, "Firulais", 25.50, -101.10)
      assert Ruta.planear(@alameda, [lejos], radio: 500).paradas == []
    end

    # ✅ REQ 7 · CASO BORDE
    test "ignora perros sin coordenadas y perros sin raza no estorban" do
      sin_gps = perro(1, "Fantasma", nil, nil)
      sin_raza = perro(2, "Chato", 25.4240, -101.0053, nil)

      plan = Ruta.planear(@alameda, [sin_gps, sin_raza], radio: 1_000)

      assert Enum.map(plan.paradas, & &1.perro.id) == [2]
    end

    # ✅ REQ 7 · CASO BORDE
    test "un perro exactamente en el borde del radio sí entra" do
      borde = perro(1, "Canela", 25.4300, -101.0053)
      radio = Geo.distancia(@alameda, Geo.punto(borde))

      assert Ruta.planear(@alameda, [borde], radio: radio).total_perros == 1
    end

    test "max se queda con los más cercanos al inicio" do
      perros = [
        perro(1, "Lejano", 25.4300, -101.0053),
        perro(2, "Cercano", 25.4240, -101.0053),
        perro(3, "Medio", 25.4270, -101.0053)
      ]

      ids = Ruta.planear(@alameda, perros, radio: 5_000, max: 2).paradas |> Enum.map(& &1.perro.id)

      assert ids == [2, 3]
    end

    test "la distancia total es la suma de los tramos" do
      perros = [
        perro(1, "A", 25.4300, -101.0000),
        perro(2, "B", 25.4250, -101.0100),
        perro(3, "C", 25.4200, -101.0020)
      ]

      plan = Ruta.planear(@alameda, perros, radio: 5_000)
      suma = plan.paradas |> Enum.map(& &1.tramo) |> Enum.sum()

      # cada tramo se redondea, así que puede diferir por unos cuantos metros
      assert abs(plan.distancia_total - suma) <= length(plan.paradas)
      assert Enum.map(plan.paradas, & &1.orden) == [1, 2, 3]
    end
  end

  describe "orden_de_visita/2" do
    test "va al más cercano desde la última parada, no desde el inicio" do
      # Desde el inicio el orden por cercanía sería b, a, c.
      # Pero estando en b, c queda más cerca que a.
      a = perro(1, "a", 0.0, 0.0025)
      b = perro(2, "b", 0.0, -0.002)
      c = perro(3, "c", 0.0, -0.004)

      assert Ruta.orden_de_visita({0.0, 0.0}, [a, b, c]) |> Enum.map(& &1.id) == [2, 3, 1]
    end

    # ✅ REQ 7 · CASO BORDE
    test "en un empate de distancias gana el id menor" do
      norte = perro(7, "Norte", 0.001, 0.0)
      sur = perro(3, "Sur", -0.001, 0.0)

      assert [%{id: 3} | _] = Ruta.orden_de_visita({0.0, 0.0}, [norte, sur])
    end

    # ✅ REQ 7 · CASO BORDE
    test "dos perros en el mismo punto se visitan los dos" do
      uno = perro(1, "Uno", 0.0, 0.001)
      otro = perro(2, "Otro", 0.0, 0.001)

      assert Ruta.orden_de_visita({0.0, 0.0}, [otro, uno]) |> Enum.map(& &1.id) == [1, 2]
    end
  end

  describe "Parametros.leer/1" do
    test "faltan coordenadas" do
      assert Parametros.leer(%{}) == {:error, "falta lat"}
    end

    test "latitud fuera de rango" do
      assert Parametros.leer(%{"lat" => "95", "lon" => "0"}) ==
               {:error, "lat debe estar entre -90 y 90"}
    end

    test "radio negativo o max no numérico" do
      assert {:error, _} = Parametros.leer(%{"lat" => "0", "lon" => "0", "radio" => "-5"})
      assert {:error, _} = Parametros.leer(%{"lat" => "0", "lon" => "0", "max" => "diez"})
    end
  end
end
