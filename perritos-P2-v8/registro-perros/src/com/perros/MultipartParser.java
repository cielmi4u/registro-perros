package com.perros;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Parser minimo de multipart/form-data (RFC 2388) escrito a mano,
 * para no depender de librerias externas (Apache Commons, etc.).
 * Soporta campos de texto normales y un archivo (la foto).
 */
public class MultipartParser {

    public static class Part {
        public String name;
        public String fileName; // null si es un campo de texto normal
        public byte[] data;

        public String asText() {
            return new String(data, StandardCharsets.UTF_8).trim();
        }
    }

    public static List<Part> parse(byte[] body, String boundary) {
        List<Part> parts = new ArrayList<>();
        byte[] boundaryBytes = ("--" + boundary).getBytes(StandardCharsets.UTF_8);

        List<Integer> boundaryIndexes = findAll(body, boundaryBytes);

        for (int i = 0; i < boundaryIndexes.size() - 1; i++) {
            int start = boundaryIndexes.get(i) + boundaryBytes.length;
            int end = boundaryIndexes.get(i + 1);
            if (start >= end) continue;

            byte[] chunk = slice(body, start, end);
            Part part = parseChunk(chunk);
            if (part != null) parts.add(part);
        }
        return parts;
    }

    private static Part parseChunk(byte[] chunk) {
        // Busca el separador \r\n\r\n entre encabezados y contenido
        int headerEnd = indexOf(chunk, "\r\n\r\n".getBytes(StandardCharsets.UTF_8), 0);
        if (headerEnd < 0) return null;

        String headers = new String(chunk, 0, headerEnd, StandardCharsets.UTF_8);
        int contentStart = headerEnd + 4;
        int contentEnd = chunk.length;
        // Quitar el \r\n final antes del siguiente boundary
        if (contentEnd >= 2 && chunk[contentEnd - 2] == '\r' && chunk[contentEnd - 1] == '\n') {
            contentEnd -= 2;
        }
        if (contentStart > contentEnd) contentStart = contentEnd;

        Part part = new Part();
        for (String line : headers.split("\r\n")) {
            String lower = line.toLowerCase();
            if (lower.startsWith("content-disposition")) {
                part.name = extractAttr(line, "name");
                part.fileName = extractAttr(line, "filename");
                if (part.fileName != null && part.fileName.isEmpty()) {
                    part.fileName = null;
                }
            }
        }
        part.data = slice(chunk, contentStart, contentEnd);
        return part;
    }

    private static String extractAttr(String header, String attr) {
        String marker = attr + "=\"";
        int idx = header.indexOf(marker);
        if (idx < 0) return null;
        int start = idx + marker.length();
        int end = header.indexOf('"', start);
        if (end < 0) return null;
        return header.substring(start, end);
    }

    private static byte[] slice(byte[] arr, int from, int to) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(arr, from, to - from);
        return out.toByteArray();
    }

    private static int indexOf(byte[] data, byte[] pattern, int from) {
        outer:
        for (int i = from; i <= data.length - pattern.length; i++) {
            for (int j = 0; j < pattern.length; j++) {
                if (data[i + j] != pattern[j]) continue outer;
            }
            return i;
        }
        return -1;
    }

    private static List<Integer> findAll(byte[] data, byte[] pattern) {
        List<Integer> result = new ArrayList<>();
        int idx = 0;
        while (true) {
            idx = indexOf(data, pattern, idx);
            if (idx < 0) break;
            result.add(idx);
            idx += pattern.length;
        }
        return result;
    }

    /** Extrae el boundary del header Content-Type: multipart/form-data; boundary=xxxx */
    public static String extractBoundary(String contentType) {
        Map<String, String> attrs = new HashMap<>();
        for (String piece : contentType.split(";")) {
            String[] kv = piece.trim().split("=", 2);
            if (kv.length == 2) attrs.put(kv[0].trim().toLowerCase(), kv[1].trim());
        }
        String boundary = attrs.get("boundary");
        if (boundary != null && boundary.startsWith("\"") && boundary.endsWith("\"")) {
            boundary = boundary.substring(1, boundary.length() - 1);
        }
        return boundary;
    }
}
