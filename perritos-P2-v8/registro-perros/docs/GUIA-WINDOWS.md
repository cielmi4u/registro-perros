# Guía rápida: funcionalidades 3 y 6 en Windows (VS Code + CMD)

Todo se hace dentro de Docker; **no instalen Elixir en Windows** (lo compilado
en Windows no sirve dentro del contenedor Linux). Sólo hace falta:

- Docker Desktop (abierto)
- Git
- VS Code. Al abrir la carpeta, acepten las extensiones recomendadas
  (Docker y resaltado de Elixir).

En VS Code, la terminal debe ser **Command Prompt**: `Ctrl+Shift+P` →
*Terminal: Select Default Profile* → *Command Prompt*.

## 1. Copiar los archivos al repositorio del P1

Copien el contenido de esta carpeta sobre su repositorio del P1 (la carpeta
donde están `src/`, `web/` y `config.properties`). Si ya habían creado
`funcional/` con `mix new`, reemplacen `mix.exs` y agreguen lo de `lib/` y
`test/`; pueden borrar `lib/perritos.ex` y `test/perritos_test.exs` que genera
`mix new`.

## 2. Primera vez

```bat
copy .env.example .env
docker compose run --rm herramientas mix local.hex --force
docker compose run --rm herramientas mix local.rebar --force
docker compose run --rm herramientas mix deps.get
docker compose run --rm herramientas mix test
```

`mix deps.get` crea `funcional\mix.lock`: ese **sí** se sube a Git.
Deben salir `22 doctests, 25 tests, 0 failures` (3 y 6 juntas).

## 3. Levantar todo

```bat
docker compose up --build
```

Esperen a ver `DATABASE IS READY TO USE!` (la primera vez, varios minutos).
Luego, en otra ventana de CMD:

```bat
curl http://localhost:8080/f/salud
curl "http://localhost:8080/f/ruta?lat=25.4232&lon=-101.0053&radio=1500&max=5"
docker compose logs tunel | findstr trycloudflare
```

```bat
curl "http://localhost:8080/f/estadisticas?dias=30&n=5"
```

Abran <http://localhost:8080>, bajen a “🚑 Ruta de rescate” → “🌳 Alameda” →
“Calcular ruta”, y a “📊 Estadísticas” (se carga sola).

## 4. Git: issue, rama y commits ligados

En GitHub creen el issue **“Funcionalidad 6: ruta de rescate”**, asígnenselo y
anoten su número (aquí se usa `#6` de ejemplo; cámbienlo por el real).

```bat
git checkout main
git pull
git checkout -b feature/ruta-rescate
```

Commits sugeridos (uno por paso, no todo junto):

```bat
git add funcional/lib/perritos/geo.ex funcional/lib/perritos/avistamiento.ex
git commit -m "Distancia haversine y struct Avistamiento (#6)"

git add funcional/lib/perritos/ruta.ex
git commit -m "Nucleo de ruta de rescate: vecino mas cercano recursivo (#6)"

git add funcional/lib/perritos/ruta/parametros.ex funcional/test/ruta_test.exs
git commit -m "Parametros de /f/ruta y pruebas ExUnit del nucleo (#6)"

git add funcional/lib/perritos/router.ex funcional/lib/perritos/datos.ex
git commit -m "Ruta GET /f/ruta en el router y lectura del backend con Req (#6)"

git add web/index.html web/style.css web/ruta.js
git commit -m "Tarjeta Ruta de rescate en el frontend del P1 (#6)"

git add README.md
git commit -m "README: documenta la ruta de rescate. Closes #6"

git push -u origin feature/ruta-rescate
```

Luego, en GitHub, abran el Pull Request a `main` y fusiónenlo (merge normal, sin
*squash*, para que se conserven los commits).

### Funcionalidad 3 (estadísticas), en su propia rama

Issue **“Funcionalidad 3: estadísticas”** (aquí `#3` de ejemplo). Quien la
hace, desde `main` ya actualizado:

```bat
git checkout main
git pull
git checkout -b feature/estadisticas

git add funcional/lib/perritos/estadisticas.ex
git commit -m "Nucleo de estadisticas: contar con reduce y top n (#3)"

git add funcional/lib/perritos/estadisticas/parametros.ex funcional/test/estadisticas_test.exs
git commit -m "Parametros de /f/estadisticas y pruebas ExUnit (#3)"

git add funcional/lib/perritos/router.ex
git commit -m "Ruta GET /f/estadisticas en el router (#3)"

git add web/index.html web/style.css web/estadisticas.js
git commit -m "Tarjeta Estadisticas con graficas en el frontend del P1 (#3)"

git add README.md
git commit -m "README: documenta estadisticas. Closes #3"

git push -u origin feature/estadisticas
```

Ojo: `router.ex`, `index.html`, `style.css` y `README.md` los tocan las dos
funcionalidades. Si cada quien trabaja en su rama, al fusionar la segunda
GitHub puede marcar conflicto; se resuelve dejando **los dos** bloques (las dos
rutas en el router, las dos tarjetas en el HTML, las dos secciones en el CSS).
Lo más fácil: fusionar primero una rama, y antes de subir la otra hacer
`git pull origin main` dentro de ella.

La parte común (`docker-compose.yml`, `Dockerfile`, `proxy/`, `.env.example`,
`DBConnection.java`, `sql/datos_muestra.sql`, `docker/`, `.vscode/`,
`mix.exs`, `application.ex`) conviene que entre antes, en su propia rama y con
su propio issue (“Infraestructura Docker del P2”), hecha por quien la acuerden.

## Si no se puede registrar o “el backend del P1 no respondió”

Revisen en este orden (en CMD, con `docker compose up` corriendo en otra ventana):

```bat
docker compose ps
curl http://localhost:8080/api/salud
docker compose logs --tail 60 bd
docker compose logs --tail 60 backend
```

| Qué ven | Qué significa | Qué hacer |
| --- | --- | --- |
| `bd` dice `health: starting` y `backend` no aparece | Oracle sigue creando la base (5–10 min la primera vez) | Esperar a `DATABASE IS READY TO USE!` en el log de `bd` |
| `bd` se reinicia o sale `Exited` | Le falta memoria a Docker | Docker Desktop → Settings → Resources: al menos 4 GB de RAM |
| `/api/salud` → `ORA-00942: table or view does not exist` | El script de tablas no corrió (la base se creó antes de que estuvieran los archivos, o el `.sh` tiene fin de línea CRLF) | `docker compose down -v` y luego `docker compose up --build` (borra la base y la crea otra vez con los scripts) |
| `/api/salud` → `ORA-01017: invalid username/password` | Cambiaron el `.env` después de crear la base | `docker compose down -v` y volver a levantar |
| `/api/salud` → `ORA-12514` o `Connection refused` | El backend apunta a otro Oracle (`BD_HOST`/`BD_SERVICIO` en `.env`) | Para el Oracle del compose: `BD_HOST=bd` y `BD_SERVICIO=XEPDB1` |
| `/api/salud` → `{"ok":true,...}` pero no registra | Ahora el mensaje de error real sale en la página, abajo del botón | Copien ese mensaje |
| “La foto es demasiado pesada” | Foto de más de 25 MB | Otra foto o bajar la resolución de la cámara |

Importante: en Docker **no** se corre `java -cp ... com.perros.Main` en Windows.
El backend vive en el contenedor `backend`. Siempre entren por
<http://localhost:8080> (el proxy), no por `localhost:8081`.

## Problemas comunes

| Síntoma | Solución |
| --- | --- |
| `bash\r: No such file` en el log de `bd` | El `.sh` quedó con fin de línea de Windows. En VS Code, abajo a la derecha cambien `CRLF` → `LF` en `docker/01-esquema.sh`, guarden y `docker compose down -v` |
| La página carga pero la ruta dice “el backend del P1 no respondió” | Oracle aún no termina de arrancar; esperen a `DATABASE IS READY TO USE!` |
| Puerto 8080 ocupado | Cambien `"8080:80"` por `"8090:80"` en `docker-compose.yml` |
| Errores raros al compilar Elixir | Borren `funcional\_build` y `funcional\deps` y repitan `mix deps.get` con herramientas |
