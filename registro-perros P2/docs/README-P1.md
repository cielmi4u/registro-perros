# Registro de perros (Java + Oracle, 100% local)

Aplicacion web local (sin subirla a internet) para registrar perros
callejeros con foto, ubicacion, nombre, raza y color. Corre desde tu
propia computadora con un servidor Java sencillo (no usa Tomcat ni
ningun servidor externo) y se abre con cualquier navegador, tanto en
la computadora como en el celular (conectado a la misma red WiFi).

## 1. Requisitos

- JDK 17 o superior instalado en la computadora que hara de servidor.
- Una base de datos Oracle accesible desde esa computadora (puede ser
  Oracle XE instalado localmente, o un Oracle en tu red).
- El driver JDBC de Oracle: **ojdbc11.jar** (o ojdbc8.jar si usas un
  JDK mas viejo). Descargalo una sola vez desde el sitio oficial de
  Oracle y colocalo en la carpeta `lib/`. Despues de eso, la app ya
  no necesita internet para funcionar.

## 1.1 Si usas Oracle 10g Express Edition

Si tu Oracle es la version 10g XE (la clasica, de instalador viejito y
32 bits), ten en cuenta:

- El nombre de servicio casi siempre es **XE** (no XEPDB1, eso es de
  Oracle 12c en adelante). Confirmalo con `lsnrctl status`: busca la
  linea "Servicio por Defecto" o la lista de servicios al final.
- El `schema.sql` de este proyecto ya esta escrito para 10g: usa
  **secuencias + triggers** para generar los IDs, en vez de columnas
  `IDENTITY` (esas llegaron hasta Oracle 12c y en 10g no existen).

## 2. Preparar la base de datos

Ejecuta el script `sql/schema.sql` en tu base Oracle (con SQL*Plus,
SQL Developer, etc.). Crea las tablas `calle`, `color`, `foto` y
`perro`, ya con las columnas extra necesarias (`raza`, `latitud`,
`longitud`, `ruta_foto`) que no aparecian completas en el diagrama
original.

Si ya tienes esas tablas creadas de otra forma, ajusta el script o el
codigo de `PerroDAO.java` para que coincida con tus nombres reales.

## 3. Configurar la conexion

Edita `config.properties` con los datos de tu Oracle:

```
db.host=localhost
db.port=1521
db.service=XEPDB1
db.user=TU_USUARIO
db.password=TU_PASSWORD
server.port=8080
```

## 4. Compilar

Desde la carpeta del proyecto:

```
javac -cp "lib/ojdbc11.jar" -d out src/com/perros/*.java
```

## 5. Ejecutar

```
java -cp "out;lib/ojdbc11.jar;." com.perros.Main      (en Windows)
java -cp "out:lib/ojdbc11.jar:." com.perros.Main      (en Mac/Linux)
```

La consola te va a mostrar algo asi:

```
Abre en esta computadora: http://localhost:8080
Desde el celular: http://192.168.1.23:8080
```

- En la misma compu, abre `http://localhost:8080` en el navegador.
- En el celular, conectado a la MISMA red WiFi que la compu, abre la
  direccion "Desde el celular" que aparecio en la consola. No hace
  falta instalar nada ni usar otra app: solo el navegador normal.

## 6. Como funciona el registro

- Al abrir la pagina, el navegador pide permiso de ubicacion y guarda
  automaticamente la latitud/longitud de donde se esta tomando la
  foto (columnas `latitud` y `longitud`, agregadas a la tabla
  `perro`).
- El campo de foto usa `capture="environment"`, que en celulares abre
  la camara trasera directamente desde el navegador.
- La fecha de registro (`fecha_registro`) la pone Oracle solo, con
  `SYSDATE`, en el momento de guardar.
- Las calles y los colores que escribas se buscan (o se crean si no
  existen) en las tablas `calle` y `color`, y se enlazan al perro con
  sus llaves foraneas, tal como en el diagrama.

## 7. Validacion de perro duplicado

Antes de insertar, el sistema revisa si ya existe un perro con el
**mismo nombre + misma calle + mismo color principal**. Si ya existe:

- No se inserta ningun registro nuevo.
- No se muestra ningun aviso de "duplicado" ni error: la pagina
  responde exactamente igual que si el registro se hubiera guardado
  (mensaje neutral "Registro procesado" y el formulario se limpia).

Si quieres cambiar el criterio de "mismo perro" (por ejemplo, incluir
la raza o los colores secundarios), edita el metodo `yaExiste(...)`
en `src/com/perros/PerroDAO.java`.

## 8. Estructura del proyecto

```
registro-perros/
 ├─ config.properties        (datos de conexion, editalos)
 ├─ sql/schema.sql           (crea las tablas en Oracle)
 ├─ lib/                     (coloca aqui ojdbc11.jar)
 ├─ fotos/                   (aqui se guardan las fotos subidas)
 ├─ src/com/perros/
 │   ├─ Main.java            (servidor web local)
 │   ├─ DBConnection.java    (conexion a Oracle)
 │   ├─ PerroDAO.java        (insercion + validacion de duplicados)
 │   └─ MultipartParser.java (lee el formulario con la foto)
 └─ web/
     ├─ index.html
     ├─ style.css
     └─ app.js
```

## Notas y supuestos

- El diagrama original no mostraba una columna de "raza" ni de
  latitud/longitud en `perro`, ni una columna para la ruta del
  archivo en `foto`: se agregaron porque el pedido las requiere. Si
  tu base real ya existe sin esas columnas, corre los `ALTER TABLE`
  correspondientes antes de usar la app.
- No se usa ningun servicio externo (como Google Maps) para convertir
  la ubicacion en nombre de calle, precisamente para que la app siga
  funcionando sin internet; por eso el nombre de calle se escribe a
  mano y la ubicacion GPS se guarda aparte, en `latitud`/`longitud`.
