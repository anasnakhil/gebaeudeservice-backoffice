-- =====================================================================
-- 02_funktionen.sql  |  Geschäftslogik in der Datenbank
-- Die n8n-Workflows rufen diese Funktionen nur auf. So liegt die Logik
-- an einer Stelle, ist testbar und unabhängig vom Automatisierungstool.
-- =====================================================================

-- ---- Angebotskalkulation ---------------------------------------------
-- Aufwand = Fläche / Leistungswert, auf Viertelstunden gerundet, mind. 1 h.
-- Preis je Einsatz = Aufwand * Verrechnungssatz.
-- Monatspreis = Preis je Einsatz * Einsätze pro Woche * 52 / 12.
CREATE OR REPLACE FUNCTION berechne_angebot(
    p_flaeche_qm          numeric,
    p_leistung_id         integer,
    p_einsaetze_pro_woche smallint
)
RETURNS TABLE (
    aufwand_h_pro_einsatz   numeric,
    preis_pro_einsatz_netto numeric,
    preis_pro_monat_netto   numeric
)
LANGUAGE sql STABLE AS $$
    SELECT a.h,
           round(a.h * l.stundensatz_netto, 2),
           round(a.h * l.stundensatz_netto * p_einsaetze_pro_woche * 52.0 / 12, 2)
    FROM leistung l,
         LATERAL (SELECT greatest(1.0, round(p_flaeche_qm / l.leistungswert_qm_pro_h * 4) / 4) AS h) a
    WHERE l.leistung_id = p_leistung_id;
$$;

-- ---- Einsatzplanung -----------------------------------------------------
-- Erzeugt für alle aktiven Aufträge die Einsätze im Zeitraum [p_von, p_bis].
-- Gibt die Anzahl NEU angelegter Einsätze zurück (bereits geplante bleiben).
CREATE OR REPLACE FUNCTION plane_einsaetze(p_von date, p_bis date)
RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    v_anzahl integer;
BEGIN
    INSERT INTO einsatz (auftrag_id, datum, geplant_h)
    SELECT au.auftrag_id, d::date, an.aufwand_h_pro_einsatz
    FROM auftrag au
    JOIN angebot an ON an.angebot_id = au.angebot_id
    CROSS JOIN LATERAL generate_series(p_von::timestamp, p_bis::timestamp, interval '1 day') AS d
    WHERE au.status = 'aktiv'
      AND d::date >= au.startdatum
      AND (au.enddatum IS NULL OR d::date <= au.enddatum)
      AND extract(isodow FROM d)::smallint = ANY (au.wochentage)
    ON CONFLICT (auftrag_id, datum) DO NOTHING;

    GET DIAGNOSTICS v_anzahl = ROW_COUNT;
    RETURN v_anzahl;
END;
$$;

-- ---- Rechnungsnummern ---------------------------------------------------
-- Format: RE-JJJJ-NNNN. Hinweis: Der Zähler läuft durchgehend und wird
-- nicht jährlich zurückgesetzt (bewusste Vereinfachung, siehe docs/).
CREATE OR REPLACE FUNCTION naechste_rechnungsnummer()
RETURNS text
LANGUAGE sql AS $$
    SELECT 'RE-' || to_char(current_date, 'YYYY') || '-' || lpad(nextval('rechnungsnummer_seq')::text, 4, '0');
$$;

-- ---- Monatsrechnung -----------------------------------------------------
-- Rechnet alle durchgeführten Einsätze eines Auftrags im Monat ab.
-- Idempotent: gibt es für Auftrag + Monat schon eine Rechnung, wird
-- deren ID zurückgegeben statt eine zweite anzulegen.
CREATE OR REPLACE FUNCTION erstelle_rechnung(p_auftrag_id integer, p_monat date)
RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    v_monat  date := date_trunc('month', p_monat)::date;
    v_id     integer;
    v_anzahl integer;
BEGIN
    SELECT rechnung_id INTO v_id
    FROM rechnung
    WHERE auftrag_id = p_auftrag_id AND leistungsmonat = v_monat;

    IF v_id IS NOT NULL THEN
        RETURN v_id;
    END IF;

    SELECT count(*) INTO v_anzahl
    FROM einsatz
    WHERE auftrag_id = p_auftrag_id
      AND status = 'durchgefuehrt'
      AND datum >= v_monat
      AND datum < (v_monat + interval '1 month')::date;

    IF v_anzahl = 0 THEN
        RAISE EXCEPTION 'Keine durchgeführten Einsätze für Auftrag % im Monat %', p_auftrag_id, v_monat;
    END IF;

    INSERT INTO rechnung (rechnungsnummer, auftrag_id, leistungsmonat, faellig_am)
    SELECT naechste_rechnungsnummer(), au.auftrag_id, v_monat, current_date + k.zahlungsziel_tage
    FROM auftrag au
    JOIN angebot an ON an.angebot_id = au.angebot_id
    JOIN kunde   k  ON k.kunde_id    = an.kunde_id
    WHERE au.auftrag_id = p_auftrag_id
    RETURNING rechnung_id INTO v_id;

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Auftrag % existiert nicht', p_auftrag_id;
    END IF;

    INSERT INTO rechnung_position (rechnung_id, beschreibung, menge, einheit, einzelpreis_netto)
    SELECT v_id,
           l.bezeichnung || ' - ' || o.bezeichnung || ' (' || to_char(v_monat, 'MM/YYYY') || ')',
           v_anzahl,
           'Einsatz',
           an.preis_pro_einsatz_netto
    FROM auftrag au
    JOIN angebot an ON an.angebot_id = au.angebot_id
    JOIN leistung l ON l.leistung_id = an.leistung_id
    JOIN objekt   o ON o.objekt_id   = an.objekt_id
    WHERE au.auftrag_id = p_auftrag_id;

    RETURN v_id;
END;
$$;
