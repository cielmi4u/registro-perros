package com.perros;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.NetworkInterface;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Enumeration;
import java.util.List;

/**
 * Servidor web local (sin depender de internet ni de un servidor externo
 * tipo Tomcat). Usa el HttpServer que ya trae el propio JDK.
 *
 * Se ejecuta en la computadora y se abre desde el navegador:
 *   - En la misma compu:  http://localhost:8080
 *   - Desde el celular (misma red WiFi que la compu): http://IP_DE_LA_COMPU:8080
 */
public class Main {

    public static void main(String[] args) throws Exception {
        int port = DBConnection.getServerPort();
        String carpetaFotos = DBConnection.getFotosCarpeta();
        new File(carpetaFotos).mkdirs();

        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/", new EstaticoHandler());
        server.createContext("/api/registrar", new RegistrarHandler(carpetaFotos));
        server.createContext("/api/perros", new ListaPerrosHandler());
        server.createContext("/fotos/", new FotosHandler(carpetaFotos));
        server.setExecutor(null);
        server.start();

        System.out.println("=================================================");
        System.out.println(" Servidor iniciado correctamente");
        System.out.println(" Abre en esta computadora: http://localhost:" + port);
        imprimirIpsLocales(port);
        System.out.println(" (usa una de esas IP desde el celular, conectado");
        System.out.println("  a la MISMA red WiFi que esta computadora)");
        System.out.println("=================================================");
    }

    private static void imprimirIpsLocales(int port) {
        try {
            Enumeration<NetworkInterface> ifaces = NetworkInterface.getNetworkInterfaces();
            while (ifaces.hasMoreElements()) {
                NetworkInterface iface = ifaces.nextElement();
                if (!iface.isUp() || iface.isLoopback()) continue;
                Enumeration<java.net.InetAddress> addrs = iface.getInetAddresses();
                while (addrs.hasMoreElements()) {
                    java.net.InetAddress addr = addrs.nextElement();
                    if (addr.getHostAddress().indexOf(':') < 0) { // solo IPv4
                        System.out.println(" Desde el celular: http://" + addr.getHostAddress() + ":" + port);
                    }
                }
            }
        } catch (Exception ignored) {
        }
    }

    /** Sirve los archivos estaticos de la carpeta web/ (html, css, js). */
    static class EstaticoHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange ex) throws IOException {
            String uri = ex.getRequestURI().getPath();
            if (uri.equals("/")) uri = "/index.html";

            Path path = Path.of("web" + uri).normalize();
            if (!path.startsWith(Path.of("web")) || !Files.exists(path) || Files.isDirectory(path)) {
                responder(ex, 404, "text/plain; charset=utf-8", "404 No encontrado");
                return;
            }

            String contentType = adivinarTipo(uri);
            byte[] contenido = Files.readAllBytes(path);
            ex.getResponseHeaders().set("Content-Type", contentType);
            ex.sendResponseHeaders(200, contenido.length);
            try (OutputStream os = ex.getResponseBody()) {
                os.write(contenido);
            }
        }

        private String adivinarTipo(String uri) {
            if (uri.endsWith(".html")) return "text/html; charset=utf-8";
            if (uri.endsWith(".css")) return "text/css; charset=utf-8";
            if (uri.endsWith(".js")) return "application/javascript; charset=utf-8";
            return "application/octet-stream";
        }
    }

    /** Recibe el formulario (multipart/form-data) con la foto y los datos del perro. */
    static class RegistrarHandler implements HttpHandler {
        private final String carpetaFotos;

        RegistrarHandler(String carpetaFotos) {
            this.carpetaFotos = carpetaFotos;
        }

        @Override
        public void handle(HttpExchange ex) throws IOException {
            if (!"POST".equalsIgnoreCase(ex.getRequestMethod())) {
                responder(ex, 405, "text/plain; charset=utf-8", "Metodo no permitido");
                return;
            }

            try {
                String contentType = ex.getRequestHeaders().getFirst("Content-Type");
                String boundary = MultipartParser.extractBoundary(contentType);
                if (boundary == null) {
                    responder(ex, 400, "text/plain; charset=utf-8", "Solicitud invalida");
                    return;
                }

                byte[] body = leerTodo(ex.getRequestBody());
                List<MultipartParser.Part> partes = MultipartParser.parse(body, boundary);

                PerroDAO.DatosPerro datos = new PerroDAO.DatosPerro();
                String rutaFotoGuardada = null;

                for (MultipartParser.Part p : partes) {
                    if (p.name == null) continue;
                    if (p.fileName != null) {
                        // Es el archivo de la foto
                        rutaFotoGuardada = guardarArchivo(p);
                    } else {
                        String valor = p.asText();
                        switch (p.name) {
                            case "nombre": datos.nombre = valor; break;
                            case "raza": datos.raza = valor; break;
                            case "calle": datos.calle = valor; break;
                            case "entreCalle1": datos.entreCalle1 = valor; break;
                            case "entreCalle2": datos.entreCalle2 = valor; break;
                            case "colorPrincipal": datos.colorPrincipal = valor; break;
                            case "colorSecundario": datos.colorSecundario = valor; break;
                            case "colorTerciario": datos.colorTerciario = valor; break;
                            case "latitud": if (!valor.isEmpty()) datos.latitud = Double.parseDouble(valor); break;
                            case "longitud": if (!valor.isEmpty()) datos.longitud = Double.parseDouble(valor); break;
                            default: break;
                        }
                    }
                }
                datos.rutaFoto = rutaFotoGuardada;

                if (datos.nombre == null || datos.nombre.trim().isEmpty()
                        || datos.calle == null || datos.calle.trim().isEmpty()
                        || datos.colorPrincipal == null || datos.colorPrincipal.trim().isEmpty()
                        || rutaFotoGuardada == null) {
                    responder(ex, 400, "application/json; charset=utf-8",
                            "{\"ok\":false,\"mensaje\":\"Faltan datos obligatorios (nombre, calle, color principal o foto)\"}");
                    return;
                }

                PerroDAO dao = new PerroDAO();
                dao.registrar(datos);
                // Nota a proposito: se responde igual sea que se haya insertado
                // o que haya sido un duplicado (no se "marca" el duplicado).
                responder(ex, 200, "application/json; charset=utf-8", "{\"ok\":true}");

            } catch (Exception e) {
                e.printStackTrace();
                responder(ex, 500, "application/json; charset=utf-8",
                        "{\"ok\":false,\"mensaje\":\"Error interno del servidor\"}");
            }
        }

        private String guardarArchivo(MultipartParser.Part p) throws IOException {
            String extension = "";
            int punto = p.fileName.lastIndexOf('.');
            if (punto >= 0) extension = p.fileName.substring(punto);
            String nombreArchivo = "perro_" + System.currentTimeMillis() + extension;
            File destino = new File(carpetaFotos, nombreArchivo);
            try (FileOutputStream fos = new FileOutputStream(destino)) {
                fos.write(p.data);
            }
            return destino.getPath();
        }

        private byte[] leerTodo(InputStream in) throws IOException {
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) != -1) bos.write(buf, 0, n);
            return bos.toByteArray();
        }
    }

    /** Devuelve, en JSON, todos los perros registrados (para el mapa y la lista de la pagina). */
    static class ListaPerrosHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange ex) throws IOException {
            if (!"GET".equalsIgnoreCase(ex.getRequestMethod())) {
                responder(ex, 405, "text/plain; charset=utf-8", "Metodo no permitido");
                return;
            }
            try {
                PerroDAO dao = new PerroDAO();
                String json = PerroDAO.aJson(dao.listar());
                responder(ex, 200, "application/json; charset=utf-8", json);
            } catch (Exception e) {
                e.printStackTrace();
                responder(ex, 500, "application/json; charset=utf-8",
                        "{\"ok\":false,\"mensaje\":\"No se pudo cargar la lista de perros\"}");
            }
        }
    }

    /** Sirve las fotos guardadas en la carpeta de fotos, a partir de /fotos/nombre-de-archivo.jpg */
    static class FotosHandler implements HttpHandler {
        private final File carpeta;

        FotosHandler(String carpetaFotos) {
            this.carpeta = new File(carpetaFotos).getAbsoluteFile();
        }

        @Override
        public void handle(HttpExchange ex) throws IOException {
            String uri = ex.getRequestURI().getPath(); // /fotos/nombre.jpg
            String nombreArchivo = uri.substring(uri.lastIndexOf('/') + 1);
            // Evita que pidan archivos fuera de la carpeta de fotos (path traversal)
            nombreArchivo = nombreArchivo.replace("..", "").replace("/", "").replace("\\", "");

            File archivo = new File(carpeta, nombreArchivo);
            if (!archivo.exists() || archivo.isDirectory()) {
                responder(ex, 404, "text/plain; charset=utf-8", "Foto no encontrada");
                return;
            }

            String tipo = "image/jpeg";
            String lower = nombreArchivo.toLowerCase();
            if (lower.endsWith(".png")) tipo = "image/png";
            else if (lower.endsWith(".webp")) tipo = "image/webp";
            else if (lower.endsWith(".gif")) tipo = "image/gif";

            byte[] datos = Files.readAllBytes(archivo.toPath());
            ex.getResponseHeaders().set("Content-Type", tipo);
            ex.sendResponseHeaders(200, datos.length);
            try (OutputStream os = ex.getResponseBody()) {
                os.write(datos);
            }
        }
    }

    private static void responder(HttpExchange ex, int codigo, String tipo, String cuerpo) throws IOException {
        byte[] bytes = cuerpo.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type", tipo);
        ex.sendResponseHeaders(codigo, bytes.length);
        try (OutputStream os = ex.getResponseBody()) {
            os.write(bytes);
        }
    }
}
