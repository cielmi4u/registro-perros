# Backend del P1 (Java 17 + HttpServer del JDK). Tambien sirve el frontend (web/).
# ---- Etapa 1: compilar ----
FROM eclipse-temurin:17-jdk AS compilar
WORKDIR /app
COPY lib lib
COPY src src
RUN javac --release 17 -cp lib/ojdbc11.jar -d out src/com/perros/*.java

# ---- Etapa 2: ejecutar ----
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=compilar /app/out out
COPY lib lib
COPY web web
# fotos de muestra (perro01.jpg … perro15.jpg) de datos_muestra.sql; al crearse el
# volumen "fotos" por primera vez, Docker copia este contenido dentro
COPY docker/muestras/ fotos/
EXPOSE 8081
CMD ["java", "-cp", "out:lib/ojdbc11.jar", "com.perros.Main"]
