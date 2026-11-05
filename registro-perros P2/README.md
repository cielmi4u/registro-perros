# 🐶 Perritos de la calle · Proyecto 2 (Java + Oracle + Elixir)

Instituto Tecnológico de Saltillo · Programación Lógica y Funcional · Unidad 2 · Prof. Daniel Varela

La app del Proyecto 1 (registro de perros callejeros con foto, nombre, raza,
colores, calle y ubicación) crece en el **mismo repositorio**: ahora tiene
funcionalidades nuevas escritas en **Elixir con estilo funcional**, todo se
levanta con **Docker** y se publica en internet con un **túnel de Cloudflare**.

> 🌐 **URL pública para la demostración:** `https://________________.trycloudflare.com`
> (cambia cada vez que se reinicia el túnel; ver [sección 3](#3-cómo-levantarla-con-docker-paso-a-paso))

---

## Índice

1. [Integrantes](#1-integrantes)
2. [Del P1 al P2](#2-del-p1-al-p2)
3. [Cómo levantarla con Docker, paso a paso](#3-cómo-levantarla-con-docker-paso-a-paso)
4. [Arquitectura](#4-arquitectura)
5. [Funcionalidades](#5-funcionalidades)
   - [3. Estadísticas](#funcionalidad-3--estadísticas)
   - [6. Ruta de rescate](#funcionalidad-6--ruta-de-rescate)
   - [Tercera funcionalidad](#tercera-funcionalidad)
6. [Cómo correr las pruebas](#6-cómo-correr-las-pruebas)
7. [Checklist de requisitos](#7-checklist-de-requisitos)
8. [Guía para la demostración](#8-guía-para-la-demostración)

---

## 1. Integrantes

| Integrante | Funcionalidad | Issue | Rama |
| --- | --- | --- | --- |
| _(nombre)_ | 3. Estadísticas | #_ | `feature/estadisticas` |
| _(nombre)_ | 6. Ruta de rescate | #_ | `feature/ruta-rescate` |
| _(nombre)_ | _(tercera funcionalidad)_ | #_ | `feature/_____` |

Equipo: Celeste Sughey Hernández Navarro, Dair Antonio Riojas Quintero y _(tercer integrante)_.

---

## 2. Del P1 al P2

### Qué había al terminar el P1

Documentado completo en [docs/README-P1.md](docs/README-P1.md).

- **Backend:** Java 17 con el `HttpServer` que trae el JDK (sin Tomcat ni frameworks).
  - `POST /api/registrar` recibe el formulario con la foto.
  - `GET /api/perros` regresa todos los perros en JSON.
  - `/fotos/...` sirve las fotos.
- **Frontend:** HTML, CSS y JavaScript sin bibliotecas (`web/`), servido por el mismo backend.
- **Base de datos:** Oracle 10g XE con las tablas `calle`, `color`, `foto` y `perro` (`sql/schema.sql`).
- Se corría a mano desde CMD con `javac` y `java`.

### Qué se agregó en el P2

| Archivo / carpeta | Para qué |
| --- | --- |
| `funcional/` | Servicio Elixir (Plug + Bandit + Jason + Req): núcleo puro, cáscara HTTP y pruebas |
| `web/estadisticas.js` | Frontend de la funcionalidad 3 |
| `web/ruta.js` | Frontend de la funcionalidad 6 |
| `docker-compose.yml` | Levanta los 5 contenedores |
| `Dockerfile` | Imagen del backend Java (2 etapas: compila con JDK, ejecuta con JRE) |
| `funcional/Dockerfile` | Imagen del servicio Elixir (2 etapas: `mix release` y sólo ejecutar) |
| `proxy/nginx.conf` | nginx, la única puerta de entrada |
| `sql/datos_muestra.sql` | 120 avistamientos de muestra alrededor de la Alameda (script versionado) |
| `docker/01-esquema.sh` | Corre `schema.sql` y `datos_muestra.sql` al crear la base en Docker |
| `docker/muestra.jpg` | Foto que usan los avistamientos de muestra |
| `.env.example` | Variables de ambiente (sin contraseñas reales) |
| `.vscode/tasks.json` | Tareas para levantar todo y correr pruebas desde VS Code |
| `docs/GUIA-WINDOWS.md` | Guía paso a paso en CMD y flujo de Git |

### Qué se modificó del P1

| Archivo | Cambio | Por qué |
| --- | --- | --- |
| `DBConnection.java` | Lee primero variables de ambiente (`DB_HOST`, `DB_SERVICE`, `DB_USER`…) y si no existen, `config.properties` | El mismo código corre en Windows y en Docker |
| `Main.java` | Nuevo `GET /api/salud`; los errores ahora dicen la causa real (p. ej. `ORA-00942`) | Diagnosticar fallas de conexión |
| `index.html` | Tarjetas “📊 Estadísticas” y “🚑 Ruta de rescate” | Usar las funcionalidades desde la app |
| `style.css` | Estilos de las dos tarjetas | |
| `app.js` | Avisa si la foto es muy pesada (413) o si el backend no responde (502) | Mensajes claros detrás del proxy |

**No se cambió ninguna tabla.** Los datos de muestra van en un script SQL versionado.

---

## 3. Cómo levantarla con Docker, paso a paso

**Único requisito:** Docker Desktop abierto (con 4 GB de RAM o más en *Settings → Resources*).

En CMD:

```bat
git clone <url-del-repositorio>
cd registro-perros
copy .env.example .env
docker compose up --build
```

En Mac/Linux, `cp .env.example .env` en lugar de `copy`.

La primera vez tarda varios minutos: se descargan las imágenes y Oracle crea la
base y carga los datos. Está lista cuando en los mensajes aparece:

```
DATABASE IS READY TO USE!
```

> ⚠️ Esa ventana se queda mostrando mensajes: **no la cierres**. Usa otra ventana
> de CMD para los demás comandos. Para que corra en segundo plano: `docker compose up -d --build`.

| Para | Abrir |
| --- | --- |
| Usar la app en la compu | <http://localhost:8080> |
| Comprobar la base | <http://localhost:8080/api/salud> → `{"ok":true,"bd":"conectada","perros":120}` |
| Comprobar el servicio Elixir | <http://localhost:8080/f/salud> → `ok` |

> ⚠️ El backend imprime `http://localhost:8081`, pero esa dirección es interna del
> contenedor. Siempre se entra por **8080** (el proxy) o por la URL del túnel.

### Obtener la URL pública (https)

```bat
docker compose logs tunel | findstr trycloudflare
```

(Mac/Linux: `| grep trycloudflare`.) La dirección `https://….trycloudflare.com`
funciona desde cualquier celular o red. Cambia cada vez que se reinicia el
contenedor `tunel`: el día de la demostración se levanta antes de clase y se
copia aquí arriba.

### Apagar

```bat
docker compose down        :: apaga, conserva la base
docker compose down -v     :: apaga y BORRA la base (se vuelve a crear al levantar)
```

### Opcional: usar el Oracle 10g XE instalado en Windows

En `.env`: `BD_HOST=host.docker.internal` y `BD_SERVICIO=XE`, y levantar sin el contenedor `bd`:

```bat
docker compose up --build --no-deps backend funcional proxy tunel
```

---

## 4. Arquitectura

```
 visitante (celular / compu)
        │  https
        ▼
 https://….trycloudflare.com
        │
        ▼
 ┌──────────────┐
 │ tunel        │  cloudflared: conexión de salida a Cloudflare
 └──────┬───────┘
        ▼
 ┌──────────────┐
 │ proxy        │  nginx :80 (publicado en localhost:8080)
 └──┬────────┬──┘
    │ /      │ /f/
    │ /api/  │
    │ /fotos/│
    ▼        ▼
 ┌──────────────┐   GET /api/perros   ┌──────────────────────────────┐
 │ backend (P1) │ ◀────────────────── │ funcional (P2, Elixir :4000) │
 │ Java :8081   │       (Req)         │  CÁSCARA: router.ex,datos.ex │
 │ sirve web/   │                     │   ┌────────────────────────┐ │
 │ y la API     │                     │   │ NÚCLEO PURO            │ │
 └──────┬───────┘                     │   │ estadisticas.ex        │ │
        │ JDBC                        │   │ ruta.ex, geo.ex        │ │
        ▼                             │   └────────────────────────┘ │
 ┌──────────────┐                     └──────────────────────────────┘
 │ bd           │  Oracle XE 21c, mismo esquema del P1
 └──────────────┘
```

### Contenedores: son 5

| Contenedor | Imagen | Qué hace |
| --- | --- | --- |
| `bd` | `gvenzl/oracle-xe:21-slim` | Base de datos Oracle con el esquema del P1 |
| `backend` | construida con `Dockerfile` | Backend Java del P1; también sirve la página (`web/`) y las fotos |
| `funcional` | construida con `funcional/Dockerfile` | Servicio Elixir con las funcionalidades nuevas |
| `proxy` | `nginx:1.27-alpine` | Única puerta de entrada; reparte por ruta |
| `tunel` | `cloudflare/cloudflared` | Publica el proxy en internet con https |

Hay un sexto servicio, `herramientas`, que **no se levanta** con `docker compose up`
(tiene un perfil): sólo se usa para correr comandos de `mix`.

En el P1 el frontend lo servía el mismo backend Java, y así se quedó: por eso no
hay un contenedor `frontend` aparte y nginx manda `/` al backend.

### Cómo obtiene los datos el servicio Elixir: **opción B**

La base es **Oracle** y entre las bibliotecas permitidas no hay driver para
Oracle (sólo Postgrex y MyXQL), así que el servicio Elixir **pide los perros al
backend del P1** con `Req`:

```
GET http://backend:8081/api/perros
```

`Perritos.Datos` (cáscara) convierte el JSON en structs `Perritos.Avistamiento`
y se los pasa al núcleo. **El núcleo nunca sabe de dónde vinieron los datos.**

nginx **no** le quita el prefijo `/api` al backend, porque las rutas del backend
Java ya empiezan con `/api/`. Al servicio Elixir le conserva el prefijo `/f`.

---

## 5. Funcionalidades

> 🔎 **Cómo encontrar cada requisito en el código:** cada requisito está marcado
> con un comentario `# ✅ REQ n`. En VS Code, `Ctrl+Shift+F` y buscar `REQ 4`
> (o `REQ 5`, `STREAM`…) lleva directo a la línea. La cáscara está marcada con `# ⚙️ CÁSCARA`.

Los 8 requisitos del paradigma que se marcan:

| | Requisito |
| --- | --- |
| REQ 1 | Núcleo de funciones puras, separado de la cáscara |
| REQ 2 | Cero estado mutable (sin Agent, GenServer, ETS ni `Enum.each`) |
| REQ 3 | Pattern matching y cláusulas múltiples en lugar de `if`/`cond` |
| REQ 4 | Orden superior: una función que **recibe** una función y una que la **regresa** |
| REQ 5 | Recursión explícita escrita por el autor |
| REQ 6 | Composición con `\|>` |
| REQ 7 | Al menos 5 pruebas ExUnit del núcleo, con al menos 2 casos borde |
| REQ 8 | `@doc` en las funciones públicas con ejemplos que corren como doctest |
| STREAM | (equipo) Al menos un `Stream` donde tenga sentido |

---

### Funcionalidad 3 · Estadísticas

**Autor:** _(nombre)_ · **Issue:** #_ · **Rama:** `feature/estadisticas`

#### Qué hace

Cuenta los avistamientos de un periodo (últimos 7, 30, 60 o 90 días) **por color,
por raza y por día**, y muestra los `n` colores y razas **más comunes**.

- Un perro con dos colores cuenta una vez en cada color.
- Una raza vacía cuenta como “Sin raza”.
- Los días sin avistamientos salen en 0, para que la gráfica no se salte días.

#### Cómo se usa en la app

Tarjeta **“📊 Estadísticas”**. Se carga sola al abrir la página.

1. Elegir el **periodo** (última semana, 30, 60 o 90 días).
2. Elegir cuántos mostrar (**Top 3, 5 o 10**).
3. Se ven:
   - barras de **colores**, pintadas con el color del perro;
   - barras de **razas**;
   - una gráfica de columnas con los **avistamientos por día**.

Todo dibujado con HTML y SVG, sin bibliotecas (`web/estadisticas.js`).

#### Endpoint

**`GET /f/estadisticas?dias=7&n=3`**

| Parámetro | Obligatorio | Por omisión | Valores |
| --- | --- | --- | --- |
| `dias` | no | 30 | 1 a 365; el periodo termina hoy |
| `n` | no | 5 | 1 a 20 |

Respuesta `200`:

```json
{
  "desde": "2026-10-30",
  "hasta": "2026-11-05",
  "dias": 7,
  "total": 14,
  "por_color": [
    {"etiqueta": "Dorado", "total": 6},
    {"etiqueta": "Blanco", "total": 4},
    {"etiqueta": "Gris", "total": 4}
  ],
  "por_raza": [
    {"etiqueta": "Sin raza", "total": 6},
    {"etiqueta": "Mestizo (criollo)", "total": 4},
    {"etiqueta": "Chihuahua", "total": 2}
  ],
  "por_dia": [
    {"fecha": "2026-10-30", "total": 2},
    {"fecha": "2026-10-31", "total": 2},
    {"fecha": "2026-11-01", "total": 2}
  ]
}
```

(`por_dia` trae un elemento por cada día del periodo; aquí se muestran 3.)

| Error | Cuándo |
| --- | --- |
| `400 {"error": "dias debe ser un entero entre 1 y 365"}` | Parámetros mal escritos o fuera de rango |
| `503 {"error": "el backend del P1 no respondió"}` | El backend o la base no están disponibles |

#### Dónde está cada requisito

Archivo principal: `funcional/lib/perritos/estadisticas.ex`

| | Requisito | Dónde (línea aprox.) | Cómo se cumple |
| :---: | --- | --- | --- |
| ✅ | **REQ 1** Núcleo puro | `estadisticas.ex` (todo el módulo) y `estadisticas/parametros.ex` | No consulta el backend ni lee el reloj: el día de hoy llega como argumento. La cáscara es `router.ex` (`get "/f/estadisticas"`, línea 43), que lee el reloj, trae los datos y responde |
| ✅ | **REQ 2** Cero estado mutable | `contar/2`, línea 112 | No hay contadores: `Enum.reduce` parte de `%{}` y en cada paso regresa un **mapa nuevo** con `Map.update` |
| ✅ | **REQ 3** Pattern matching | `extractor/1` (43), `etiqueta_raza/1` (77), `dia/1` (82), `rellenar/4` (159), `Parametros.entero/4` | Una cláusula por caso: `:color`/`:raza`/`:dia`; `nil`/`""`/otra raza; `nil`/`Date`/`NaiveDateTime`; `:gt` termina la recursión |
| ✅ | **REQ 4** Recibe una función | `contar(avistamientos, extraer)`, línea 112 | `extraer` decide bajo qué claves se cuenta cada perro |
| ✅ | **REQ 4** Regresa una función | `extractor/1` (43) y `en_periodo/2` (60) | `extractor(:color)` regresa `fn perro -> colores end`; `en_periodo` regresa un filtro |
| ✅ | **REQ 5** Recursión explícita | `rellenar/4`, líneas 159–167 | Arma el día actual y se llama con el día siguiente hasta pasarse del último |
| ✅ | **REQ 6** Composición con `\|>` | `resumen/3` (195), `mas_comunes/2` (126), `contar/2` (112) | `periodo \|> contar(extractor(:color)) \|> mas_comunes(n)` |
| ✅ | **REQ 7** Pruebas | `test/estadisticas_test.exs` | **13 pruebas + 9 doctests**, 7 casos borde marcados |
| ✅ | **REQ 8** `@doc` con doctests | todas las funciones públicas | Cada `@doc` trae ejemplos `iex>` que corren con `doctest` |
| ✅ | **STREAM** | `resumen/3` línea 200 y `contar/2` línea 114 | El periodo es un `Stream.filter`; `contar` usa `Stream.flat_map`. Las mismas funciones sirven con una lista o con un Stream (prueba “lista y Stream dan lo mismo”) |

**Casos borde probados (REQ 7):** sin avistamientos · periodo de un solo día ·
raza `nil` y raza `""` · perro sin fecha · color repetido en el mismo perro ·
empate en el top (se ordena alfabéticamente) · `n = 0` · `n` mayor que el total.

---

### Funcionalidad 6 · Ruta de rescate

**Autor:** _(nombre)_ · **Issue:** #_ · **Rama:** `feature/ruta-rescate`

#### Qué hace

Dado un **punto de partida** y un **radio**, toma los perros que están dentro de
esa zona y propone **en qué orden visitarlos** con la heurística del **vecino más
cercano**:

1. Ir al perro más cercano.
2. Quitarlo de la lista.
3. Repetir desde ahí con los que quedan.

Calcula la distancia de cada tramo y la total, con la fórmula de **haversine**.

#### Cómo se usa en la app

Tarjeta **“🚑 Ruta de rescate”**:

1. Elegir el inicio: **“📡 Mi ubicación”**, **“🌳 Alameda”** o escribir latitud y longitud.
2. Elegir el **radio** (500 m a 5 km) y el **máximo** de perros.
3. **“Calcular ruta”**: se dibuja el recorrido numerado (★ = inicio) y la lista
   de paradas con foto, calle, metros del tramo y acumulados.

#### Endpoint

**`GET /f/ruta?lat=25.4232&lon=-101.0053&radio=1500&max=10`**

| Parámetro | Obligatorio | Por omisión | Significado |
| --- | --- | --- | --- |
| `lat`, `lon` | **sí** | — | Punto de partida, en grados |
| `radio` | no | 2000 | Metros alrededor del inicio que forman la zona |
| `max` | no | todos | Sólo los `max` perros más cercanos al inicio |

Respuesta `200`:

```json
{
  "inicio": {"lat": 25.4232, "lon": -101.0053},
  "radio": 1500,
  "total_perros": 3,
  "distancia_total": 1950,
  "paradas": [
    {"orden": 1, "tramo": 278, "acumulada": 278,
     "perro": {"id": 14, "nombre": "Rocky", "raza": null, "colores": ["Negro"],
               "calle": "Victoria", "lat": 25.4251, "lon": -101.0071,
               "foto": "/fotos/muestra.jpg", "fecha": "2026-10-30"}},
    {"orden": 2, "tramo": 459, "acumulada": 737,
     "perro": {"id": 41, "nombre": "Chato", "calle": "Allende", "lat": 25.4274, "lon": -101.0109}},
    {"orden": 3, "tramo": 1213, "acumulada": 1950,
     "perro": {"id": 3, "nombre": "Canela", "calle": "Hidalgo", "lat": 25.4209, "lon": -101.0012}}
  ]
}
```

(Se recortaron campos de los perros 2 y 3 para que se lea mejor.) Canela está
más cerca del inicio que Chato, pero estando en Rocky conviene ir primero a
Chato: eso es el **vecino más cercano**.

| Error | Cuándo |
| --- | --- |
| `400 {"error": "lat debe ser un número"}` | Falta `lat`/`lon` o están mal escritos |
| `503 {"error": "el backend del P1 no respondió"}` | El backend o la base no están disponibles |

#### Dónde está cada requisito

Archivo principal: `funcional/lib/perritos/ruta.ex` (y `geo.ex` para haversine)

| | Requisito | Dónde (línea aprox.) | Cómo se cumple |
| :---: | --- | --- | --- |
| ✅ | **REQ 1** Núcleo puro | `ruta.ex`, `geo.ex`, `ruta/parametros.ex` | Reciben perros y regresan un mapa; no hacen peticiones. La cáscara es `router.ex` (`get "/f/ruta"`, línea 25) y `datos.ex` |
| ✅ | **REQ 2** Cero estado mutable | todo el módulo | La lista de pendientes no se modifica: cada llamada recursiva recibe una **lista nueva** sin el perro visitado (`List.delete`) |
| ✅ | **REQ 3** Pattern matching | `con_ubicacion?/1` (69), `visitar/3` (111), `distancia_total/1` (162), `limitar/3` (211), `Parametros.numero/2` | Cláusulas: con/sin coordenadas; lista vacía (caso base) / con pendientes; sin/con máximo |
| ✅ | **REQ 4** Recibe una función | `mas_cercano(perros, medir)`, línea 88 | `medir` dice qué tan lejos está cada perro; regresa el menor (empate → id menor) |
| ✅ | **REQ 4** Regresa una función | `distancia_desde/1` (36) y `en_zona/2` (51) | `distancia_desde(punto)` regresa `fn perro -> metros end`; `en_zona` regresa un filtro |
| ✅ | **REQ 5** Recursión explícita | `visitar/3`, líneas 111–116 | Toma el más cercano, lo quita y **se llama a sí misma** con los que quedan, desde la posición de ese perro |
| ✅ | **REQ 6** Composición con `\|>` | `planear/3` (190), `tramos/2` (137) | filtrar con ubicación → zona → limitar → ordenar → tramos |
| ✅ | **REQ 7** Pruebas | `test/ruta_test.exs` | **12 pruebas + 13 doctests**, 6 casos borde marcados |
| ✅ | **REQ 8** `@doc` con doctests | todas las funciones públicas | Ejemplos `iex>` en `Ruta`, `Geo` y `Parametros` |
| ✅ | **STREAM** | `tramos/2`, líneas 137–150 | Pares consecutivos con `Stream.chunk_every`, distancias con `Stream.map`, acumulado con `Stream.scan` y `Stream.zip`; todo se calcula una sola vez al final |

**Casos borde probados (REQ 7):** sin perros · nadie dentro del radio · perro sin
GPS y sin raza · perro justo en el borde del radio (sí entra) · empate de
distancias (gana el id menor) · dos perros en el mismo punto.

---

### Tercera funcionalidad

**Autor:** _(nombre)_ · **Issue:** #_ · **Rama:** `feature/_____`

_(por completar con el mismo formato: qué hace, cómo se usa, endpoint y tabla de requisitos)_

---

## 6. Cómo correr las pruebas

No necesitan la base de datos ni el servidor: el alias `test: "test --no-start"`
de `mix.exs` hace que sólo se pruebe el núcleo. Todo corre dentro de Docker.

**Sólo la primera vez:**

```bat
docker compose run --rm herramientas mix local.hex --force
docker compose run --rm herramientas mix local.rebar --force
docker compose run --rm herramientas mix deps.get
```

**Correr todas las pruebas:**

```bat
docker compose run --rm herramientas mix test
```

Resultado esperado con las funcionalidades 3 y 6:

```
22 doctests, 25 tests, 0 failures
```

| Archivo | Pruebas | Doctests |
| --- | :---: | :---: |
| `test/estadisticas_test.exs` | 13 | 9 |
| `test/ruta_test.exs` | 12 | 13 |

Desde VS Code: `Ctrl+Shift+P` → **Tasks: Run Test Task**.

---

## 7. Checklist de requisitos

### Por funcionalidad

| Requisito | 3. Estadísticas | 6. Ruta de rescate | 3ª funcionalidad |
| --- | :---: | :---: | :---: |
| REQ 1 · Núcleo puro separado | ✅ | ✅ | ⬜ |
| REQ 2 · Cero estado mutable | ✅ | ✅ | ⬜ |
| REQ 3 · Pattern matching | ✅ | ✅ | ⬜ |
| REQ 4 · Recibe una función | ✅ | ✅ | ⬜ |
| REQ 4 · Regresa una función | ✅ | ✅ | ⬜ |
| REQ 5 · Recursión explícita | ✅ | ✅ | ⬜ |
| REQ 6 · Composición con `\|>` | ✅ | ✅ | ⬜ |
| REQ 7 · ≥ 5 pruebas, ≥ 2 casos borde | ✅ 13 / 7 | ✅ 12 / 6 | ⬜ |
| REQ 8 · `@doc` con doctests | ✅ 9 | ✅ 13 | ⬜ |
| Se usa desde el frontend | ✅ | ✅ | ⬜ |

### Por equipo

| Requisito | | Dónde |
| --- | :---: | --- |
| Al menos un `Stream` | ✅ | `estadisticas.ex` (`resumen/3`, `contar/2`) y `ruta.ex` (`tramos/2`) |
| `mix test` corre y pasan todas | ✅ | 22 doctests, 25 tests, 0 failures |
| Bibliotecas permitidas (sin Phoenix) | ✅ | Plug, Bandit, Jason, Req (`funcional/mix.exs`) |
| Dockerfile de Elixir en 2 etapas con `mix release` | ✅ | `funcional/Dockerfile` |
| `docker-compose.yml` levanta todo | ✅ | bd, backend, funcional, proxy, tunel |
| `.env` no se sube, `.env.example` sí | ✅ | `.gitignore` |
| Fotos en un volumen de Docker | ✅ | volumen `fotos` montado en `/app/fotos` |
| Proxy nginx como única entrada | ✅ | `proxy/nginx.conf` |
| Frontend con rutas relativas (`/api/…`, `/f/…`) | ✅ | `web/app.js`, `web/ruta.js`, `web/estadisticas.js` |
| Túnel de Cloudflare | ✅ | servicio `tunel` |
| Al menos 100 avistamientos de muestra | ✅ | 120 en `sql/datos_muestra.sql` |
| Mismo modelo de datos del P1 | ✅ | no se cambió ninguna tabla |
| Un issue por funcionalidad, cerrado con `Closes #n` | ⬜ | _(marcar al cerrar los issues)_ |

---

## 8. Guía para la demostración

### Antes de clase

```bat
docker compose up -d --build
docker compose logs tunel | findstr trycloudflare
```

Copiar la URL arriba en este README y mandarla al profesor. Probarla desde un
celular **con datos móviles** (fuera del Wi-Fi).

### Paso 4: cada integrante abre su núcleo

| Funcionalidad | Abrir |
| --- | --- |
| 3. Estadísticas | `funcional/lib/perritos/estadisticas.ex` |
| 6. Ruta de rescate | `funcional/lib/perritos/ruta.ex` |

Con `Ctrl+Shift+F` → `REQ` aparecen todos los requisitos marcados.

### Paso 5: respuestas a las preguntas

#### ❓ ¿Qué hace la característica que añadiste?

- **Estadísticas:** cuenta los avistamientos de un periodo por color, por raza y
  por día, y muestra los más comunes con gráficas.
- **Ruta de rescate:** desde un punto de partida, propone en qué orden visitar a
  los perros de una zona yendo siempre al más cercano, y dice cuántos metros se
  recorren en total.

#### ❓ Muéstrame una función que recibe una función

| Funcionalidad | Función | Línea |
| --- | --- | --- |
| Estadísticas | `contar(avistamientos, extraer)` — `extraer` dice bajo qué claves cuenta cada perro | `estadisticas.ex:112` |
| Ruta de rescate | `mas_cercano(perros, medir)` — `medir` dice qué tan lejos está cada perro | `ruta.ex:88` |

Y las que **regresan** una función: `extractor/1` y `en_periodo/2` (estadísticas);
`distancia_desde/1` y `en_zona/2` (ruta).

#### ❓ Muéstrame el uso del Stream

| Funcionalidad | Dónde | Qué hace |
| --- | --- | --- |
| Estadísticas | `resumen/3` (`estadisticas.ex:200`) | `Stream.filter` toma sólo los perros del periodo **sin crear una lista nueva** |
| Estadísticas | `contar/2` (`estadisticas.ex:114`) | `Stream.flat_map` saca los colores de cada perro; la misma función sirve con lista o con Stream |
| Ruta de rescate | `tramos/2` (`ruta.ex:140`) | `Stream.chunk_every` arma pares de puntos, `Stream.map` mide cada tramo, `Stream.scan` acumula; se evalúa una sola vez al final |

#### ❓ ¿Cuántos contenedores son?

**Cinco:** `bd` (Oracle), `backend` (Java del P1, también sirve la página),
`funcional` (Elixir), `proxy` (nginx) y `tunel` (Cloudflare). El servicio
`herramientas` existe pero no se levanta: sólo sirve para correr `mix`.

```bat
docker compose ps
```

#### ❓ Otras que pueden preguntar

| Pregunta | Respuesta corta |
| --- | --- |
| ¿Por qué el núcleo no lee la fecha de hoy? | Leer el reloj es un efecto: daría otro resultado cada día y no se podría probar. Lo lee la cáscara (`router.ex`) y se lo pasa al núcleo |
| ¿Dónde está la cáscara? | `router.ex` (HTTP y reloj) y `datos.ex` (red, Req contra el backend) |
| ¿Por qué opción B y no A? | La base es Oracle y no hay driver permitido para Oracle |
| ¿Dónde está la recursión? | `visitar/3` en `ruta.ex:111` y `rellenar/4` en `estadisticas.ex:159` |
| ¿Por qué no hay contadores? | `Enum.reduce` regresa un mapa nuevo en cada paso; nada se modifica |
