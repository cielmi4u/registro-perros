package com.perros;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

/**
 * Logica de negocio para registrar un perro.
 *
 * Criterio de "mismo perro" (duplicado):
 *   mismo nombre (sin importar mayusculas/espacios) + misma calle + mismo color principal.
 * Ajusta el metodo yaExiste(...) si prefieres otro criterio (por ejemplo, agregar la raza).
 *
 * Si se detecta duplicado, NO se inserta nada y NO se lanza ningun error:
 * el metodo simplemente devuelve false, y quien lo llama responde igual
 * que si todo hubiera salido bien (para no "marcar" el duplicado).
 */
public class PerroDAO {

    /** Devuelve true si el registro se guardo, false si era un duplicado y no se guardo nada. */
    public boolean registrar(DatosPerro d) throws SQLException {
        try (Connection con = getConn()) {
            con.setAutoCommit(false);
            try {
                Integer idCalle = buscarOCrearCalle(con, d.calle);
                Integer idEntreCalle1 = buscarOCrearCalle(con, d.entreCalle1);
                Integer idEntreCalle2 = buscarOCrearCalle(con, d.entreCalle2);
                Integer idColorPrincipal = buscarOCrearColor(con, d.colorPrincipal);
                Integer idColorSecundario = buscarOCrearColor(con, d.colorSecundario);
                Integer idColorTerciario = buscarOCrearColor(con, d.colorTerciario);

                if (yaExiste(con, d.nombre, idCalle, idColorPrincipal)) {
                    con.rollback();
                    return false; // duplicado: no se inserta nada, sin error visible
                }

                int idFoto = guardarFoto(con, d.rutaFoto);

                String sql = "INSERT INTO perro "
                        + "(nombre, raza, calle_idcalle, entre_calle_idcalle1, entre_calle1_idcalle2, "
                        + " color_idcolor, seg_color_idcolor1, ter_color_idcolor1, foto_idfoto, "
                        + " fecha_registro, latitud, longitud) "
                        + "VALUES (?,?,?,?,?,?,?,?,?, SYSDATE, ?, ?)";
                try (PreparedStatement ps = con.prepareStatement(sql)) {
                    ps.setString(1, d.nombre);
                    ps.setString(2, d.raza);
                    ps.setInt(3, idCalle);
                    setNullableInt(ps, 4, idEntreCalle1);
                    setNullableInt(ps, 5, idEntreCalle2);
                    ps.setInt(6, idColorPrincipal);
                    setNullableInt(ps, 7, idColorSecundario);
                    setNullableInt(ps, 8, idColorTerciario);
                    ps.setInt(9, idFoto);
                    setNullableDouble(ps, 10, d.latitud);
                    setNullableDouble(ps, 11, d.longitud);
                    ps.executeUpdate();
                }

                con.commit();
                return true;
            } catch (SQLException e) {
                con.rollback();
                throw e;
            }
        }
    }

    private boolean yaExiste(Connection con, String nombre, int idCalle, int idColorPrincipal) throws SQLException {
        String sql = "SELECT COUNT(*) FROM perro "
                + "WHERE UPPER(TRIM(nombre)) = UPPER(TRIM(?)) "
                + "AND calle_idcalle = ? AND color_idcolor = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, nombre);
            ps.setInt(2, idCalle);
            ps.setInt(3, idColorPrincipal);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getInt(1) > 0;
            }
        }
    }

    private Integer buscarOCrearCalle(Connection con, String nombreCalle) throws SQLException {
        if (nombreCalle == null || nombreCalle.trim().isEmpty()) return null;
        String buscar = "SELECT idcalle FROM calle WHERE UPPER(TRIM(nom_calle)) = UPPER(TRIM(?))";
        try (PreparedStatement ps = con.prepareStatement(buscar)) {
            ps.setString(1, nombreCalle);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1);
            }
        }
        String insertar = "INSERT INTO calle (nom_calle) VALUES (?)";
        try (PreparedStatement ps = con.prepareStatement(insertar, new String[]{"idcalle"})) {
            ps.setString(1, nombreCalle.trim());
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                rs.next();
                return rs.getInt(1);
            }
        }
    }

    private Integer buscarOCrearColor(Connection con, String nombreColor) throws SQLException {
        if (nombreColor == null || nombreColor.trim().isEmpty()) return null;
        String buscar = "SELECT idcolor FROM color WHERE UPPER(TRIM(color)) = UPPER(TRIM(?))";
        try (PreparedStatement ps = con.prepareStatement(buscar)) {
            ps.setString(1, nombreColor);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1);
            }
        }
        String insertar = "INSERT INTO color (color) VALUES (?)";
        try (PreparedStatement ps = con.prepareStatement(insertar, new String[]{"idcolor"})) {
            ps.setString(1, nombreColor.trim());
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                rs.next();
                return rs.getInt(1);
            }
        }
    }

    private int guardarFoto(Connection con, String rutaFoto) throws SQLException {
        String sql = "INSERT INTO foto (ruta_foto) VALUES (?)";
        try (PreparedStatement ps = con.prepareStatement(sql, new String[]{"idfoto"})) {
            ps.setString(1, rutaFoto);
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                rs.next();
                return rs.getInt(1);
            }
        }
    }

    private void setNullableInt(PreparedStatement ps, int idx, Integer value) throws SQLException {
        if (value == null) ps.setNull(idx, java.sql.Types.INTEGER);
        else ps.setInt(idx, value);
    }

    private void setNullableDouble(PreparedStatement ps, int idx, Double value) throws SQLException {
        if (value == null) ps.setNull(idx, java.sql.Types.NUMERIC);
        else ps.setDouble(idx, value);
    }

    private Connection getConn() throws SQLException {
        try {
            return DBConnection.getConnection();
        } catch (java.io.IOException e) {
            throw new SQLException("No se pudo leer config.properties", e);
        }
    }

    /** Trae todos los perros registrados, con nombres de calle y color ya resueltos, para el mapa y la lista. */
    public List<PerroInfo> listar() throws SQLException {
        String sql = "SELECT p.idperro, p.nombre, p.raza, "
                + "c1.color AS color_principal, c2.color AS color_secundario, c3.color AS color_terciario, "
                + "cl.nom_calle AS calle, ec1.nom_calle AS entre_calle1, ec2.nom_calle AS entre_calle2, "
                + "p.fecha_registro, p.latitud, p.longitud, f.ruta_foto "
                + "FROM perro p "
                + "JOIN color c1 ON c1.idcolor = p.color_idcolor "
                + "LEFT JOIN color c2 ON c2.idcolor = p.seg_color_idcolor1 "
                + "LEFT JOIN color c3 ON c3.idcolor = p.ter_color_idcolor1 "
                + "JOIN calle cl ON cl.idcalle = p.calle_idcalle "
                + "LEFT JOIN calle ec1 ON ec1.idcalle = p.entre_calle_idcalle1 "
                + "LEFT JOIN calle ec2 ON ec2.idcalle = p.entre_calle1_idcalle2 "
                + "JOIN foto f ON f.idfoto = p.foto_idfoto "
                + "ORDER BY p.fecha_registro DESC";

        List<PerroInfo> lista = new ArrayList<>();
        try (Connection con = getConn();
             Statement st = con.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) {
                PerroInfo p = new PerroInfo();
                p.id = rs.getInt("idperro");
                p.nombre = rs.getString("nombre");
                p.raza = rs.getString("raza");
                p.colorPrincipal = rs.getString("color_principal");
                p.colorSecundario = rs.getString("color_secundario");
                p.colorTerciario = rs.getString("color_terciario");
                p.calle = rs.getString("calle");
                p.entreCalle1 = rs.getString("entre_calle1");
                p.entreCalle2 = rs.getString("entre_calle2");
                java.sql.Date fecha = rs.getDate("fecha_registro");
                p.fecha = (fecha != null) ? fecha.toString() : "";
                double lat = rs.getDouble("latitud");
                p.latitud = rs.wasNull() ? null : lat;
                double lng = rs.getDouble("longitud");
                p.longitud = rs.wasNull() ? null : lng;
                String rutaFoto = rs.getString("ruta_foto");
                p.archivoFoto = new java.io.File(rutaFoto).getName();
                lista.add(p);
            }
        }
        return lista;
    }

    /** Convierte la lista de perros a un JSON simple, sin depender de librerias externas. */
    public static String aJson(List<PerroInfo> lista) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < lista.size(); i++) {
            PerroInfo p = lista.get(i);
            if (i > 0) sb.append(",");
            sb.append("{")
              .append("\"id\":").append(p.id).append(",")
              .append("\"nombre\":").append(jsonStr(p.nombre)).append(",")
              .append("\"raza\":").append(jsonStr(p.raza)).append(",")
              .append("\"colorPrincipal\":").append(jsonStr(p.colorPrincipal)).append(",")
              .append("\"colorSecundario\":").append(jsonStr(p.colorSecundario)).append(",")
              .append("\"colorTerciario\":").append(jsonStr(p.colorTerciario)).append(",")
              .append("\"calle\":").append(jsonStr(p.calle)).append(",")
              .append("\"entreCalle1\":").append(jsonStr(p.entreCalle1)).append(",")
              .append("\"entreCalle2\":").append(jsonStr(p.entreCalle2)).append(",")
              .append("\"fecha\":").append(jsonStr(p.fecha)).append(",")
              .append("\"lat\":").append(p.latitud == null ? "null" : p.latitud).append(",")
              .append("\"lng\":").append(p.longitud == null ? "null" : p.longitud).append(",")
              .append("\"foto\":").append(jsonStr("/fotos/" + p.archivoFoto))
              .append("}");
        }
        sb.append("]");
        return sb.toString();
    }

    private static String jsonStr(String valor) {
        if (valor == null) valor = "";
        String escapado = valor.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", " ")
                .replace("\r", " ");
        return "\"" + escapado + "\"";
    }

    /** Datos ya resueltos de un perro registrado, listos para mostrar en el mapa/lista. */
    public static class PerroInfo {
        public int id;
        public String nombre;
        public String raza;
        public String colorPrincipal;
        public String colorSecundario;
        public String colorTerciario;
        public String calle;
        public String entreCalle1;
        public String entreCalle2;
        public String fecha;
        public Double latitud;
        public Double longitud;
        public String archivoFoto;
    }

    /** Datos que llegan desde el formulario web. */
    public static class DatosPerro {
        public String nombre;
        public String raza;
        public String calle;
        public String entreCalle1;
        public String entreCalle2;
        public String colorPrincipal;
        public String colorSecundario;
        public String colorTerciario;
        public String rutaFoto;
        public Double latitud;
        public Double longitud;
    }
}
