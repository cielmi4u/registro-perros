package com.perros;

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
            try (FileInputStream fis = new FileInputStream("config.properties")) {
                props.load(fis);
            }
        }
        return props;
    }

    public static Connection getConnection() throws SQLException, IOException {
        Properties p = getProps();
        String host = p.getProperty("db.host");
        String port = p.getProperty("db.port");
        String service = p.getProperty("db.service");
        String user = p.getProperty("db.user");
        String pass = p.getProperty("db.password");

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
        return getProps().getProperty("fotos.carpeta", "fotos");
    }

    public static int getServerPort() throws IOException {
        return Integer.parseInt(getProps().getProperty("server.port", "8080"));
    }
}
