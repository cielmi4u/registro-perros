-- ============================================================
-- Esquema Oracle SQL para el sistema de registro de perros
-- Compatible con Oracle 10g Express Edition (no soporta columnas
-- IDENTITY, que llegaron hasta Oracle 12c), por eso los IDs se
-- generan con SECUENCIA + TRIGGER, la forma clasica en 10g.
-- ============================================================
-- NOTA IMPORTANTE (cambios respecto al diagrama original):
--  1. Se agregan las columnas RAZA, LATITUD y LONGITUD a PERRO,
--     porque el diagrama no las incluia pero se piden en el requerimiento.
--  2. Se agrega la columna RUTA_FOTO a FOTO para guardar la ubicacion
--     del archivo de imagen en disco (el diagrama solo mostraba IDFOTO).
--  Si tu tabla real ya existe y no quieres tocarla, puedes correr solo
--  los ALTER TABLE que necesites, o ajustar el codigo Java para que no
--  use esas columnas.
-- ============================================================

-- ---------- CALLE ----------
CREATE TABLE calle (
    idcalle     NUMBER PRIMARY KEY,
    nom_calle   VARCHAR2(45) NOT NULL,
    CONSTRAINT uq_calle_nombre UNIQUE (nom_calle)
);

CREATE SEQUENCE seq_calle START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE TRIGGER trg_calle_id
BEFORE INSERT ON calle
FOR EACH ROW
WHEN (NEW.idcalle IS NULL)
BEGIN
    SELECT seq_calle.NEXTVAL INTO :NEW.idcalle FROM dual;
END;
/

-- ---------- COLOR ----------
CREATE TABLE color (
    idcolor     NUMBER PRIMARY KEY,
    color       VARCHAR2(45) NOT NULL,
    CONSTRAINT uq_color_nombre UNIQUE (color)
);

CREATE SEQUENCE seq_color START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE TRIGGER trg_color_id
BEFORE INSERT ON color
FOR EACH ROW
WHEN (NEW.idcolor IS NULL)
BEGIN
    SELECT seq_color.NEXTVAL INTO :NEW.idcolor FROM dual;
END;
/

-- ---------- FOTO ----------
CREATE TABLE foto (
    idfoto      NUMBER PRIMARY KEY,
    ruta_foto   VARCHAR2(500) NOT NULL
);

CREATE SEQUENCE seq_foto START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE TRIGGER trg_foto_id
BEFORE INSERT ON foto
FOR EACH ROW
WHEN (NEW.idfoto IS NULL)
BEGIN
    SELECT seq_foto.NEXTVAL INTO :NEW.idfoto FROM dual;
END;
/

-- ---------- PERRO ----------
CREATE TABLE perro (
    idperro                 NUMBER PRIMARY KEY,
    nombre                  VARCHAR2(45)  NOT NULL,
    raza                    VARCHAR2(45),
    calle_idcalle           NUMBER        NOT NULL,
    entre_calle_idcalle1    NUMBER,
    entre_calle1_idcalle2   NUMBER,
    color_idcolor           NUMBER        NOT NULL,
    seg_color_idcolor1      NUMBER,
    ter_color_idcolor1      NUMBER,
    foto_idfoto             NUMBER        NOT NULL,
    fecha_registro          DATE DEFAULT SYSDATE NOT NULL,
    latitud                 NUMBER(10,7),
    longitud                NUMBER(10,7),
    CONSTRAINT fk_perro_calle       FOREIGN KEY (calle_idcalle)         REFERENCES calle(idcalle),
    CONSTRAINT fk_perro_entrecalle1 FOREIGN KEY (entre_calle_idcalle1)  REFERENCES calle(idcalle),
    CONSTRAINT fk_perro_entrecalle2 FOREIGN KEY (entre_calle1_idcalle2) REFERENCES calle(idcalle),
    CONSTRAINT fk_perro_color       FOREIGN KEY (color_idcolor)         REFERENCES color(idcolor),
    CONSTRAINT fk_perro_color2      FOREIGN KEY (seg_color_idcolor1)    REFERENCES color(idcolor),
    CONSTRAINT fk_perro_color3      FOREIGN KEY (ter_color_idcolor1)    REFERENCES color(idcolor),
    CONSTRAINT fk_perro_foto        FOREIGN KEY (foto_idfoto)           REFERENCES foto(idfoto)
);

CREATE SEQUENCE seq_perro START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE TRIGGER trg_perro_id
BEFORE INSERT ON perro
FOR EACH ROW
WHEN (NEW.idperro IS NULL)
BEGIN
    SELECT seq_perro.NEXTVAL INTO :NEW.idperro FROM dual;
END;
/

-- Indice util para la validacion de duplicados (nombre + calle + color principal)
CREATE INDEX ix_perro_duplicado ON perro (nombre, calle_idcalle, color_idcolor);
