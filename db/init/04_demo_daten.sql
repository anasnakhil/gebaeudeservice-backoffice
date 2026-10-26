-- =====================================================================
-- 04_demo_daten.sql  |  Fiktive Demo-Daten
-- ACHTUNG: Alle Firmen, Adressen, Preise und Löhne sind frei erfunden und
-- dienen nur zum Ausprobieren. Es sind KEINE echten Kundendaten.
-- Die IDs sind bei einer frischen Datenbank 1, 2, 3 ... (Identity-Spalten).
-- =====================================================================

INSERT INTO kunde (firmenname, ansprechpartner, email, strasse, plz, ort, zahlungsziel_tage) VALUES
 ('Beispiel Steuerberatung GmbH', 'Frau Beispiel', 'kontakt@beispiel-stb.example', 'Musterstraße 1',   '45127', 'Essen', 14),
 ('Praxis Dr. Muster',            'Herr Muster',   'praxis@muster.example',        'Beispielallee 12', '45128', 'Essen', 14),
 ('Hausverwaltung Demo KG',       'Frau Demo',     'info@demo-hv.example',         'Probeweg 5',       '45130', 'Essen', 10);

INSERT INTO objekt (kunde_id, bezeichnung, strasse, plz, ort, flaeche_qm, objektart, zugang_hinweis) VALUES
 (1, 'Büro 2. OG',        'Musterstraße 1',   '45127', 'Essen', 220.00, 'Buero',       'Schlüsselbox am Hintereingang'),
 (2, 'Arztpraxis EG',     'Beispielallee 12', '45128', 'Essen', 140.00, 'Praxis',      'Zugang nach 18 Uhr'),
 (3, 'Treppenhaus Haus A','Probeweg 5',       '45130', 'Essen',  90.00, 'Treppenhaus', NULL);

-- Leistungswerte und Sätze sind Demo-Annahmen.
INSERT INTO leistung (bezeichnung, leistungswert_qm_pro_h, stundensatz_netto) VALUES
 ('Unterhaltsreinigung Büro', 150.00, 34.00),
 ('Treppenhausreinigung',     120.00, 34.00),
 ('Glasreinigung',             80.00, 38.00),
 ('Praxisreinigung',          100.00, 36.00);

INSERT INTO mitarbeiter (vorname, nachname, kostensatz_pro_h, wochenstunden_soll) VALUES
 ('Mitarbeiter', 'A', 20.00, 20.00),
 ('Mitarbeiter', 'B', 21.50, 15.00);

-- ---- Angebote (Preise kommen aus der Funktion berechne_angebot) --------
INSERT INTO angebot (kunde_id, objekt_id, leistung_id, einsaetze_pro_woche,
                     aufwand_h_pro_einsatz, preis_pro_einsatz_netto, status, gueltig_bis)
SELECT 1, 1, 1, 3, b.aufwand_h_pro_einsatz, b.preis_pro_einsatz_netto, 'angenommen', date '2026-09-30'
FROM berechne_angebot(220, 1, 3::smallint) b;

INSERT INTO angebot (kunde_id, objekt_id, leistung_id, einsaetze_pro_woche,
                     aufwand_h_pro_einsatz, preis_pro_einsatz_netto, status, gueltig_bis)
SELECT 2, 2, 4, 5, b.aufwand_h_pro_einsatz, b.preis_pro_einsatz_netto, 'angenommen', date '2026-09-30'
FROM berechne_angebot(140, 4, 5::smallint) b;

INSERT INTO angebot (kunde_id, objekt_id, leistung_id, einsaetze_pro_woche,
                     aufwand_h_pro_einsatz, preis_pro_einsatz_netto, status, gueltig_bis)
SELECT 3, 3, 2, 1, b.aufwand_h_pro_einsatz, b.preis_pro_einsatz_netto, 'angenommen', date '2026-09-30'
FROM berechne_angebot(90, 2, 1::smallint) b;

-- Ein offenes Angebot ohne Auftrag (Glasreinigung für Kunde 1)
INSERT INTO angebot (kunde_id, objekt_id, leistung_id, einsaetze_pro_woche,
                     aufwand_h_pro_einsatz, preis_pro_einsatz_netto, status, gueltig_bis)
SELECT 1, 1, 3, 1, b.aufwand_h_pro_einsatz, b.preis_pro_einsatz_netto, 'versendet', date '2026-11-30'
FROM berechne_angebot(220, 3, 1::smallint) b;

-- ---- Aufträge (aus den angenommenen Angeboten) ---------------------------
INSERT INTO auftrag (angebot_id, startdatum, wochentage, status) VALUES
 (1, '2026-09-01', ARRAY[1,3,5]::smallint[],     'aktiv'),   -- Mo, Mi, Fr
 (2, '2026-09-01', ARRAY[1,2,3,4,5]::smallint[], 'aktiv'),   -- Mo bis Fr
 (3, '2026-09-01', ARRAY[2]::smallint[],         'aktiv');   -- Di

-- ---- Einsätze planen und bis 23.10.2026 als durchgeführt markieren --------
SELECT plane_einsaetze(date '2026-09-01', date '2026-10-31');

UPDATE einsatz
SET status = 'durchgefuehrt',
    mitarbeiter_id = (auftrag_id % 2) + 1,
    qualitaet_ok = (extract(day FROM datum)::int <> 17)   -- am 17. gab es Beanstandungen (Demo)
WHERE datum <= date '2026-10-23';

-- Ist-Zeiten: geplante Stunden, an jedem 5. Tag eine halbe Stunde länger
INSERT INTO zeiterfassung (einsatz_id, mitarbeiter_id, stunden)
SELECT einsatz_id,
       mitarbeiter_id,
       geplant_h + CASE WHEN extract(day FROM datum)::int % 5 = 0 THEN 0.5 ELSE 0 END
FROM einsatz
WHERE status = 'durchgefuehrt';

INSERT INTO kosten (auftrag_id, monat, art, betrag_netto) VALUES
 (1, '2026-09-01', 'Reinigungsmittel', 18.50),
 (2, '2026-09-01', 'Reinigungsmittel', 24.00),
 (3, '2026-09-01', 'Reinigungsmittel',  6.80);

-- ---- September abrechnen --------------------------------------------------
SELECT erstelle_rechnung(auftrag_id, date '2026-09-01') FROM auftrag;

UPDATE rechnung r
SET rechnungsdatum = date '2026-10-01',
    faellig_am     = date '2026-10-01' + k.zahlungsziel_tage,
    status         = 'versendet'
FROM auftrag au
JOIN angebot an ON an.angebot_id = au.angebot_id
JOIN kunde   k  ON k.kunde_id    = an.kunde_id
WHERE au.auftrag_id = r.auftrag_id;

-- Kunden 1 und 2 haben bezahlt, Kunde 3 ist offen (und überfällig)
INSERT INTO zahlung (rechnung_id, betrag, zahlungsdatum)
SELECT rechnung_id, brutto, date '2026-10-05'
FROM v_rechnung_summe
WHERE auftrag_id IN (1, 2);

UPDATE rechnung SET status = 'bezahlt' WHERE auftrag_id IN (1, 2);
