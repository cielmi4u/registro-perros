package com.perros;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;

/**
 * Encargada de abrir conexiones a la base de datos Oracle
 * usando los datos de config.properties.
 */
public class DBConnection {

    private static Properties props;

    private static synchronized Properties getProps() throws IOException {
        if (props == null) {
            props = new Properties();
            File archivo = new File("config.properties");
            // P2: dentro de Docker no hay config.properties; los datos
            // llegan por variables de ambiente (ver valor() mas abajo).
            if (archivo.exists()) {
                try (FileInputStream fis = new FileInputStream(archivo)) {
                    props.load(fis);
                }
            }
        }
        return props;
    }

    /**
     * P2: primero busca la variable de ambiente (p. ej. DB_HOST para db.host),
     * si no existe usa config.properties y si tampoco, el valor por omision.
     * Asi la misma clase sirve en Windows (config.properties) y en Docker (.env).
     */
    private static String valor(String clave, String omision) throws IOException {
        String env = System.getenv(clave.toUpperCase().replace('.', '_'));
        if (env != null && !env.isEmpty()) return env;
        return getProps().getProperty(clave, omision);
    }

    public static Connection getConnection() throws SQLException, IOException {
        String host = valor("db.host", "localhost");
        String port = valor("db.port", "1521");
        String service = valor("db.service", "XE");
        String user = valor("db.user", null);
        String pass = valor("db.password", null);

        String url = "jdbc:oracle:thin:@//" + host + ":" + port + "/" + service;

        // El driver ojdbc8.jar (o ojdbc11.jar) debe estar en el classpath.
        // Desde Java 6+ no es obligatorio Class.forName, pero lo dejamos
        // por compatibilidad con versiones viejas del driver.
        try {
            Class.forName("oracle.jdbc.OracleDriver");
        } catch (ClassNotFoundException e) {
            throw new SQLException("No se encontro el driver de Oracle (ojdbc). "
                    + "Revisa que el .jar este en la carpeta lib/ y en el classpath.", e);
        }

        return DriverManager.getConnection(url, user, pass);
    }

    public static String getFotosCarpeta() throws IOException {
        return valor("fotos.carpeta", "fotos");
    }

    public static int getServerPort() throws IOException {
        return Integer.parseInt(valor("server.port", "8081"));
    }
}
