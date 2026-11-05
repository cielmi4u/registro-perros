#!/bin/bash
# Lo ejecuta el contenedor gvenzl/oracle-xe UNA sola vez, al crear la base.
# Corre el esquema del P1 y los datos de muestra del P2 con el usuario
# de la aplicacion (APP_USER, creado por la imagen en XEPDB1).
sqlplus -s "${APP_USER}/${APP_USER_PASSWORD}@//localhost/XEPDB1" <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
@/sql/schema.sql
@/sql/datos_muestra.sql
EXIT
SQL
