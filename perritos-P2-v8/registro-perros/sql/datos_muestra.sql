-- ============================================================
-- P2 · Datos de muestra: 15 perritos reales (fotos/perro01.jpg ...
-- perro15.jpg), 20 avistamientos en total: 5 de ellos se volvieron a
-- ver en otro lugar. Todos estan a menos de ~3.5 km del
-- Instituto Tecnologico de Saltillo (25.44175, -100.99284) y de la
-- Zona Centro (Plaza de Armas, 25.42179, -101.00039).
-- Cada foto tiene sus colores y raza (lo que se ve en la foto).
-- No agrega columnas ni tablas: usa el modelo del P1 tal cual.
-- Los acentos se escriben con UNISTR para no depender del NLS_LANG.
-- ============================================================
DECLARE
  TYPE t_ids IS TABLE OF NUMBER;
  fotos  t_ids := t_ids();
  v_foto NUMBER;

  FUNCTION id_calle(p_nombre VARCHAR2) RETURN NUMBER IS
    v NUMBER;
  BEGIN
    SELECT idcalle INTO v FROM calle WHERE UPPER(nom_calle) = UPPER(p_nombre);
    RETURN v;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    INSERT INTO calle (nom_calle) VALUES (p_nombre) RETURNING idcalle INTO v;
    RETURN v;
  END;

  FUNCTION id_color(p_nombre VARCHAR2) RETURN NUMBER IS
    v NUMBER;
  BEGIN
    IF p_nombre IS NULL THEN RETURN NULL; END IF;
    SELECT idcolor INTO v FROM color WHERE UPPER(color) = UPPER(p_nombre);
    RETURN v;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    INSERT INTO color (color) VALUES (p_nombre) RETURNING idcolor INTO v;
    RETURN v;
  END;

  -- inserta un avistamiento (las funciones se llaman antes del INSERT)
  PROCEDURE perro(p_foto NUMBER, p_nombre VARCHAR2, p_raza VARCHAR2,
                  p_color1 VARCHAR2, p_color2 VARCHAR2, p_calle VARCHAR2,
                  p_hace_dias NUMBER, p_lat NUMBER, p_lon NUMBER) IS
    v_calle  NUMBER := id_calle(p_calle);
    v_c1     NUMBER := id_color(p_color1);
    v_c2     NUMBER := id_color(p_color2);
    v_idfoto NUMBER := fotos(p_foto);
  BEGIN
    INSERT INTO perro (nombre, raza, calle_idcalle, color_idcolor, seg_color_idcolor1,
                       foto_idfoto, fecha_registro, latitud, longitud)
    VALUES (p_nombre, p_raza, v_calle, v_c1, v_c2, v_idfoto,
            TRUNC(SYSDATE) - p_hace_dias + 10/24, p_lat, p_lon);
  END;
BEGIN
  -- una fila en FOTO por cada imagen
  FOR f IN 1 .. 15 LOOP
    fotos.EXTEND;
    INSERT INTO foto (ruta_foto) VALUES ('fotos/perro' || LPAD(f, 2, '0') || '.jpg')
      RETURNING idfoto INTO v_foto;
    fotos(f) := v_foto;
  END LOOP;

  --     foto  nombre      raza                 color 1                      color 2          calle                                 hace dias  latitud     longitud
  perro( 1, 'Firulais', 'Mestizo (criollo)', 'Negro', 'Blanco', 'Blvd. Francisco Coss',  2, 25.4271756, -100.9864426);
  perro( 2, 'Gordo', 'Mestizo (criollo)', 'Blanco', 'Negro', 'Victoria',  5, 25.4270766, -101.0038542);
  perro( 3, 'Pinto', NULL, 'Blanco', UNISTR('Caf\00E9'), 'Hidalgo',  1, 25.4174193, -101.0002562);
  perro( 4, 'Manchas', 'Mestizo (criollo)', 'Manchado (blanco y negro)', NULL, 'Blvd. Nazario Ortiz Garza',  9, 25.4476882, -100.9898881);
  perro( 5, 'Canelo', 'Pitbull', 'Blanco', UNISTR('Caf\00E9'), UNISTR('Calle Tecnol\00F3gico'),  3, 25.4395724, -100.9925559);
  perro( 6, 'Rocky', 'Mestizo (criollo)', 'Negro', 'Canela', UNISTR('Xicot\00E9ncatl'), 14, 25.4127777, -100.9858158);
  perro( 7, 'Chispa', 'Chihuahua', 'Negro', 'Canela', 'Calle Reynosa',  6, 25.4402885, -100.9873204);
  perro( 8, 'Solovino', NULL, UNISTR('Caf\00E9'), 'Blanco', 'Ramos Arizpe', 20, 25.4159186, -101.0147093);
  perro( 9, 'Canela', 'Mestizo (criollo)', 'Canela', NULL, 'Allende',  4, 25.4182669, -101.0044807);
  perro(10, 'Flojo', NULL, UNISTR('Caf\00E9'), 'Blanco', UNISTR('Calle Tecnol\00F3gico'), 11, 25.4388612, -100.9977917);
  perro(11, 'Pelusa', NULL, 'Crema', NULL, 'Madero',  8, 25.4401603, -101.008064);
  perro(12, 'Max', 'Mestizo (criollo)', 'Negro', 'Canela', 'Abasolo', 17, 25.4241479, -100.9746849);
  perro(13, 'Oso', 'Pitbull', 'Negro', 'Blanco', 'Av. Universidad',  1, 25.4394146, -100.9784085);
  perro(14, 'Negrito', 'Mestizo (criollo)', 'Negro', 'Blanco', UNISTR('Xicot\00E9ncatl'), 25, 25.4222324, -101.0092022);
  perro(15, 'Luna', NULL, 'Negro', NULL, UNISTR('P\00E9rez Trevi\00F1o'),  7, 25.4243818, -100.9991422);
  perro( 1, 'Firulais', 'Mestizo (criollo)', 'Negro', 'Blanco', 'Ramos Arizpe', 12, 25.4250894, -101.0124359);
  perro( 4, 'Manchas', 'Mestizo (criollo)', 'Manchado (blanco y negro)', NULL, 'Allende', 22, 25.418837, -100.9922731);
  perro( 6, 'Rocky', 'Mestizo (criollo)', 'Negro', 'Canela', 'Purcell',  3, 25.4372027, -101.0176213);
  perro(13, 'Oso', 'Pitbull', 'Negro', 'Blanco', 'Madero', 16, 25.4324389, -100.9766644);
  perro(15, 'Luna', NULL, 'Negro', NULL, UNISTR('Ju\00E1rez'), 28, 25.4101175, -101.0004394);
  COMMIT;
END;
/
