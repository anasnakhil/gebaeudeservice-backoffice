-- =====================================================================
-- 01_schema.sql  |  Datenmodell des Gebäudeservice-Backoffice
-- PostgreSQL 16. Wird beim ersten Start des Containers automatisch
-- ausgeführt (docker-entrypoint-initdb.d, alphabetische Reihenfolge).
-- =====================================================================

-- ---------- Stammdaten ------------------------------------------------

CREATE TABLE kunde (
    kunde_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    firmenname        text    NOT NULL,
    ansprechpartner   text,
    email             text,
    telefon           text,
    strasse           text    NOT NULL,
    plz               text    NOT NULL CHECK (plz ~ '^[0-9]{5}$'),
    ort               text    NOT NULL,
    zahlungsziel_tage integer NOT NULL DEFAULT 14 CHECK (zahlungsziel_tage >= 0),
    erstellt_am       timestamptz NOT NULL DEFAULT now()
);

-- Ein Kunde kann mehrere Objekte (Standorte) haben.
CREATE TABLE objekt (
    objekt_id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kunde_id       integer NOT NULL REFERENCES kunde (kunde_id),
    bezeichnung    text    NOT NULL,
    strasse        text    NOT NULL,
    plz            text    NOT NULL CHECK (plz ~ '^[0-9]{5}$'),
    ort            text    NOT NULL,
    flaeche_qm     numeric(10,2) NOT NULL CHECK (flaeche_qm > 0),
    objektart      text    NOT NULL
                   CHECK (objektart IN ('Buero', 'Praxis', 'Treppenhaus', 'Gewerbe', 'Sonstiges')),
    zugang_hinweis text
);

-- Leistungskatalog: Leistungswert (qm pro Stunde) und Verrechnungssatz.
-- Aus beidem berechnet berechne_angebot() Aufwand und Preis.
CREATE TABLE leistung (
    leistung_id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bezeichnung            text    NOT NULL UNIQUE,
    leistungswert_qm_pro_h numeric(8,2) NOT NULL CHECK (leistungswert_qm_pro_h > 0),
    stundensatz_netto      numeric(8,2) NOT NULL CHECK (stundensatz_netto > 0)
);

CREATE TABLE mitarbeiter (
    mitarbeiter_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vorname            text NOT NULL,
    nachname           text NOT NULL,
    kostensatz_pro_h   numeric(8,2) NOT NULL CHECK (kostensatz_pro_h > 0),  -- Lohn inkl. Nebenkosten
    wochenstunden_soll numeric(5,2) NOT NULL CHECK (wochenstunden_soll > 0),
    aktiv              boolean NOT NULL DEFAULT true
);

-- ---------- Vertrieb: Angebot -> Auftrag ---------------------------------

CREATE TABLE angebot (
    angebot_id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kunde_id                integer NOT NULL REFERENCES kunde (kunde_id),
    objekt_id               integer NOT NULL REFERENCES objekt (objekt_id),
    leistung_id             integer NOT NULL REFERENCES leistung (leistung_id),
    einsaetze_pro_woche     smallint NOT NULL CHECK (einsaetze_pro_woche BETWEEN 1 AND 7),
    aufwand_h_pro_einsatz   numeric(6,2)  NOT NULL CHECK (aufwand_h_pro_einsatz > 0),
    preis_pro_einsatz_netto numeric(10,2) NOT NULL CHECK (preis_pro_einsatz_netto > 0),
    status                  text NOT NULL DEFAULT 'entwurf'
                            CHECK (status IN ('entwurf', 'versendet', 'angenommen', 'abgelehnt')),
    erstellt_am             date NOT NULL DEFAULT current_date,
    gueltig_bis             date
);

-- Ein angenommenes Angebot wird zum Auftrag (1:1).
-- wochentage: ISO-Zählung, 1 = Montag ... 7 = Sonntag.
CREATE TABLE auftrag (
    auftrag_id  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    angebot_id  integer NOT NULL UNIQUE REFERENCES angebot (angebot_id),
    startdatum  date NOT NULL,
    enddatum    date,
    wochentage  smallint[] NOT NULL
                CHECK (cardinality(wochentage) > 0
                       AND wochentage <@ ARRAY[1,2,3,4,5,6,7]::smallint[]),
    status      text NOT NULL DEFAULT 'aktiv'
                CHECK (status IN ('aktiv', 'pausiert', 'beendet')),
    CHECK (enddatum IS NULL OR enddatum >= startdatum)
);

-- ---------- Betrieb: Einsatzplanung und Zeiterfassung --------------------

CREATE TABLE einsatz (
    einsatz_id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    auftrag_id      integer NOT NULL REFERENCES auftrag (auftrag_id),
    mitarbeiter_id  integer REFERENCES mitarbeiter (mitarbeiter_id),
    datum           date NOT NULL,
    geplant_h       numeric(5,2) NOT NULL CHECK (geplant_h > 0),
    status          text NOT NULL DEFAULT 'geplant'
                    CHECK (status IN ('geplant', 'durchgefuehrt', 'ausgefallen')),
    qualitaet_ok    boolean,          -- NULL = noch nicht geprüft
    notiz           text,
    UNIQUE (auftrag_id, datum)        -- macht die Planung wiederholbar (idempotent)
);

CREATE TABLE zeiterfassung (
    zeit_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    einsatz_id      integer NOT NULL REFERENCES einsatz (einsatz_id),
    mitarbeiter_id  integer NOT NULL REFERENCES mitarbeiter (mitarbeiter_id),
    stunden         numeric(5,2) NOT NULL CHECK (stunden > 0)
);

-- Materialkosten (Reinigungsmittel etc.) je Auftrag und Monat.
CREATE TABLE kosten (
    kosten_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    auftrag_id    integer NOT NULL REFERENCES auftrag (auftrag_id),
    monat         date NOT NULL CHECK (monat = date_trunc('month', monat)::date),
    art           text NOT NULL,
    betrag_netto  numeric(10,2) NOT NULL CHECK (betrag_netto >= 0)
);

-- ---------- Finanzen: Rechnung und Zahlung ---------------------------------

CREATE SEQUENCE rechnungsnummer_seq START 1;

CREATE TABLE rechnung (
    rechnung_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rechnungsnummer text NOT NULL UNIQUE,
    auftrag_id      integer NOT NULL REFERENCES auftrag (auftrag_id),
    leistungsmonat  date NOT NULL CHECK (leistungsmonat = date_trunc('month', leistungsmonat)::date),
    rechnungsdatum  date NOT NULL DEFAULT current_date,
    faellig_am      date NOT NULL,
    ust_satz        numeric(4,2) NOT NULL DEFAULT 19.00,
    status          text NOT NULL DEFAULT 'entwurf'
                    CHECK (status IN ('entwurf', 'versendet', 'bezahlt', 'storniert')),
    pdf_pfad        text,
    UNIQUE (auftrag_id, leistungsmonat)  -- pro Auftrag und Monat nur eine Rechnung
);

CREATE TABLE rechnung_position (
    position_id        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rechnung_id        integer NOT NULL REFERENCES rechnung (rechnung_id) ON DELETE CASCADE,
    beschreibung       text NOT NULL,
    menge              numeric(10,2) NOT NULL CHECK (menge > 0),
    einheit            text NOT NULL,
    einzelpreis_netto  numeric(10,2) NOT NULL CHECK (einzelpreis_netto >= 0)
);

CREATE TABLE zahlung (
    zahlung_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rechnung_id    integer NOT NULL REFERENCES rechnung (rechnung_id),
    betrag         numeric(10,2) NOT NULL CHECK (betrag > 0),
    zahlungsdatum  date NOT NULL
);

-- ---------- Indizes auf Fremdschlüsseln (Joins beschleunigen) ----------------

CREATE INDEX idx_objekt_kunde      ON objekt (kunde_id);
CREATE INDEX idx_angebot_kunde     ON angebot (kunde_id);
CREATE INDEX idx_einsatz_datum     ON einsatz (datum);
CREATE INDEX idx_zeit_einsatz      ON zeiterfassung (einsatz_id);
CREATE INDEX idx_zeit_mitarbeiter  ON zeiterfassung (mitarbeiter_id);
CREATE INDEX idx_kosten_auftrag    ON kosten (auftrag_id, monat);
CREATE INDEX idx_position_rechnung ON rechnung_position (rechnung_id);
CREATE INDEX idx_zahlung_rechnung  ON zahlung (rechnung_id);
