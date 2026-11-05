-- ============================================================
-- P2 · Datos de muestra: 120 avistamientos alrededor del centro de
-- Saltillo (Alameda Zaragoza, 25.4232, -101.0053), en un cuadro de
-- unos 7 x 7 km, con fechas de los ultimos 60 dias.
-- No agrega columnas ni tablas: usa el modelo del P1 tal cual.
-- Compatible con Oracle 10g XE y con el Oracle 21c XE del compose.
-- Sin acentos a proposito, para no depender del NLS_LANG del cliente.
-- Todos usan la misma foto de muestra: fotos/muestra.jpg
-- ============================================================
DECLARE
  TYPE t_lista IS TABLE OF VARCHAR2(45);
  nombres t_lista := t_lista('Firulais','Chato','Canela','Negrito','Manchas','Pinto',
                             'Lobo','Princesa','Solovino','Peluche','Coco','Bombon',
                             'Tobi','Rocky','Luna','Kira','Max','Pelusa','Chispa','Oso');
  razas   t_lista := t_lista(NULL,'Mestizo (criollo)',NULL,'Labrador','Chihuahua',NULL,
                             'Pitbull','Schnauzer',NULL,'Pastor Aleman');
  calles  t_lista := t_lista('Allende','Victoria','Hidalgo','Juarez','Aldama','Zaragoza',
                             'Xicotencatl','Bravo','Perez Trevino','Ramos Arizpe',
                             'Venustiano Carranza','Abasolo','Madero','Purcell','Obregon');
  colores t_lista := t_lista('Negro','Blanco','Dorado','Gris','Atigrado','Canela',
                             'Crema','Tricolor');
  v_foto  NUMBER;
  v_calle NUMBER;
  v_c1    NUMBER;
  v_c2    NUMBER;
  v_raza  VARCHAR2(45);
  v_nombre VARCHAR2(45);

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
    SELECT idcolor INTO v FROM color WHERE UPPER(color) = UPPER(p_nombre);
    RETURN v;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    INSERT INTO color (color) VALUES (p_nombre) RETURNING idcolor INTO v;
    RETURN v;
  END;

  FUNCTION al_azar(p_lista t_lista) RETURN VARCHAR2 IS
  BEGIN
    RETURN p_lista(TRUNC(DBMS_RANDOM.VALUE(1, p_lista.COUNT + 1)));
  END;
BEGIN
  DBMS_RANDOM.SEED(2026);  -- siempre los mismos datos
  INSERT INTO foto (ruta_foto) VALUES ('fotos/muestra.jpg') RETURNING idfoto INTO v_foto;

  FOR i IN 1 .. 120 LOOP
    -- las funciones locales no se pueden llamar dentro del INSERT,
    -- por eso se calculan antes en variables
    v_nombre := nombres(MOD(i - 1, nombres.COUNT) + 1);
    v_raza  := al_azar(razas);
    v_calle := id_calle(al_azar(calles));
    v_c1    := id_color(al_azar(colores));
    IF MOD(i, 2) = 0 THEN v_c2 := id_color(al_azar(colores)); ELSE v_c2 := NULL; END IF;

    INSERT INTO perro (nombre, raza, calle_idcalle, color_idcolor, seg_color_idcolor1,
                       foto_idfoto, fecha_registro, latitud, longitud)
    VALUES (v_nombre,
            v_raza,
            v_calle,
            v_c1,
            v_c2,
            v_foto,
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(0, 60)),
            ROUND(25.4232   + DBMS_RANDOM.VALUE(-0.035, 0.035), 7),
            ROUND(-101.0053 + DBMS_RANDOM.VALUE(-0.035, 0.035), 7));
  END LOOP;
  COMMIT;
END;
/
