defmodule Perritos.EstadisticasTest do
  # ✅ REQ 7 · PRUEBAS ExUnit del núcleo, sin servidor ni base de datos.
  # ✅ REQ 8 · doctest: corre como prueba cada ejemplo iex> de los @doc
  use ExUnit.Case, async: true

  doctest Perritos.Estadisticas
  doctest Perritos.Estadisticas.Parametros

  alias Perritos.{Avistamiento, Estadisticas}
  alias Perritos.Estadisticas.Parametros

  @hoy ~D[2026-11-05]

  defp perro(id, colores, raza, fecha) do
    %Avistamiento{id: id, nombre: "Perro #{id}", colores: colores, raza: raza, fecha: fecha}
  end

  defp muestra do
    [
      perro(1, ["Negro", "Blanco"], nil, ~D[2026-11-05]),
      perro(2, ["Negro"], "Labrador", ~D[2026-11-05]),
      perro(3, ["Dorado"], "Labrador", ~D[2026-11-03]),
      perro(4, ["Blanco"], "", ~D[2026-11-01]),
      perro(5, ["Gris"], "Chihuahua", ~D[2026-08-15])
    ]
  end

  describe "resumen/3" do
    # ✅ REQ 7 · CASO BORDE
    test "sin avistamientos: total 0, listas vacías y días en cero" do
      r = Estadisticas.resumen([], @hoy, n: 5, dias: 3)

      assert r.total == 0
      assert r.por_color == []
      assert r.por_raza == []
      assert Enum.map(r.por_dia, & &1.total) == [0, 0, 0]
    end

    test "cuenta sólo los del periodo" do
      r = Estadisticas.resumen(muestra(), @hoy, dias: 30)

      assert r.total == 4
      assert r.desde == ~D[2026-10-07]
      refute Enum.any?(r.por_color, &(&1.etiqueta == "Gris"))
    end

    # ✅ REQ 7 · CASO BORDE
    test "raza nil y raza vacía cuentan juntas como Sin raza" do
      r = Estadisticas.resumen(muestra(), @hoy, dias: 30)

      assert %{etiqueta: "Sin raza", total: 2} in r.por_raza
      assert %{etiqueta: "Labrador", total: 2} in r.por_raza
    end

    test "la serie diaria tiene un elemento por día, de desde a hoy" do
      r = Estadisticas.resumen(muestra(), @hoy, dias: 5)

      assert Enum.map(r.por_dia, & &1.fecha) ==
               [~D[2026-11-01], ~D[2026-11-02], ~D[2026-11-03], ~D[2026-11-04], ~D[2026-11-05]]

      assert Enum.map(r.por_dia, & &1.total) == [1, 0, 1, 0, 2]
    end

    # ✅ REQ 7 · CASO BORDE
    test "un periodo de un solo día" do
      r = Estadisticas.resumen(muestra(), @hoy, dias: 1)
      assert r.total == 2
      assert r.por_dia == [%{fecha: @hoy, total: 2}]
    end
  end

  describe "contar/2" do
    test "lista y Stream dan lo mismo" do
      lista = muestra()
      flujo = Stream.map(lista, & &1)

      for clave <- [:color, :raza, :dia] do
        assert Estadisticas.contar(lista, Estadisticas.extractor(clave)) ==
                 Estadisticas.contar(flujo, Estadisticas.extractor(clave))
      end
    end

    # ✅ REQ 7 · CASO BORDE
    test "un perro con el mismo color repetido cuenta una sola vez" do
      repetido = perro(9, ["Negro", "Negro"], nil, @hoy)
      assert Estadisticas.contar([repetido], Estadisticas.extractor(:color)) == %{"Negro" => 1}
    end

    # ✅ REQ 7 · CASO BORDE
    test "un perro sin fecha no cuenta en ningún día" do
      sin_fecha = perro(9, ["Negro"], nil, nil)
      assert Estadisticas.contar([sin_fecha], Estadisticas.extractor(:dia)) == %{}
    end

    test "acepta cualquier función extractora" do
      por_id_par = fn p -> [rem(p.id, 2) == 0] end
      assert Estadisticas.contar(muestra(), por_id_par) == %{true => 2, false => 3}
    end
  end

  describe "mas_comunes/2" do
    # ✅ REQ 7 · CASO BORDE
    test "empate se ordena alfabéticamente y n mayor que el total no truena" do
      conteos = %{"Negro" => 2, "Blanco" => 2, "Dorado" => 1}

      assert Estadisticas.mas_comunes(conteos, 10) == [
               %{etiqueta: "Blanco", total: 2},
               %{etiqueta: "Negro", total: 2},
               %{etiqueta: "Dorado", total: 1}
             ]
    end

    # ✅ REQ 7 · CASO BORDE
    test "n = 0 regresa lista vacía" do
      assert Estadisticas.mas_comunes(%{"Negro" => 3}, 0) == []
    end
  end

  describe "Parametros.leer/1" do
    test "sin parámetros usa los valores por omisión" do
      assert Parametros.leer(%{}) == {:ok, [n: 5, dias: 30]}
    end

    test "fuera de rango" do
      assert {:error, _} = Parametros.leer(%{"n" => "0"})
      assert {:error, _} = Parametros.leer(%{"dias" => "400"})
    end
  end
end
