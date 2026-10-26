-- =====================================================================
-- 03_views.sql  |  Kennzahlen (KPI-Tracking, Marge, Auslastung)
-- Views speichern keine Daten, sondern benannte Abfragen. Reporting-
-- Tools wie Metabase oder Excel greifen direkt auf sie zu.
-- =====================================================================

-- Rechnungssummen: netto, Umsatzsteuer, brutto, bereits gezahlt
CREATE VIEW v_rechnung_summe AS
SELECT r.rechnung_id,
       r.rechnungsnummer,
       r.auftrag_id,
       r.leistungsmonat,
       r.status,
       r.faellig_am,
       n.netto,
       round(n.netto * r.ust_satz / 100, 2)            AS ust,
       n.netto + round(n.netto * r.ust_satz / 100, 2)  AS brutto,
       coalesce(zl.gezahlt, 0)                         AS gezahlt
FROM rechnung r
LEFT JOIN LATERAL (
    SELECT coalesce(sum(p.menge * p.einzelpreis_netto), 0)::numeric(12,2) AS netto
    FROM rechnung_position p
    WHERE p.rechnung_id = r.rechnung_id
) n ON true
LEFT JOIN LATERAL (
    SELECT sum(z.betrag) AS gezahlt
    FROM zahlung z
    WHERE z.rechnung_id = r.rechnung_id
) zl ON true;

-- Umsatz je Monat (stornierte Rechnungen zählen nicht)
CREATE VIEW v_umsatz_monat AS
SELECT leistungsmonat AS monat,
       sum(netto)     AS umsatz_netto,
       count(*)       AS anzahl_rechnungen
FROM v_rechnung_summe
WHERE status <> 'storniert'
GROUP BY leistungsmonat;

-- Offene Posten inkl. Überfälligkeit
CREATE VIEW v_offene_posten AS
SELECT s.rechnungsnummer,
       k.firmenname,
       s.leistungsmonat,
       s.faellig_am,
       s.brutto,
       s.gezahlt,
       s.brutto - s.gezahlt                      AS offen,
       greatest(current_date - s.faellig_am, 0)  AS tage_ueberfaellig
FROM v_rechnung_summe s
JOIN auftrag au ON au.auftrag_id = s.auftrag_id
JOIN angebot an ON an.angebot_id = au.angebot_id
JOIN kunde   k  ON k.kunde_id    = an.kunde_id
WHERE s.status <> 'storniert'
  AND s.brutto - s.gezahlt > 0;

-- Marge je Auftrag und Monat: Umsatz - Personalkosten - Materialkosten
CREATE VIEW v_marge_auftrag_monat AS
WITH umsatz AS (
    SELECT auftrag_id, leistungsmonat AS monat, sum(netto) AS umsatz_netto
    FROM v_rechnung_summe
    WHERE status <> 'storniert'
    GROUP BY auftrag_id, leistungsmonat
), personal AS (
    SELECT e.auftrag_id,
           date_trunc('month', e.datum)::date   AS monat,
           sum(zt.stunden)                      AS stunden,
           sum(zt.stunden * m.kostensatz_pro_h) AS personalkosten
    FROM zeiterfassung zt
    JOIN einsatz     e ON e.einsatz_id     = zt.einsatz_id
    JOIN mitarbeiter m ON m.mitarbeiter_id = zt.mitarbeiter_id
    GROUP BY e.auftrag_id, date_trunc('month', e.datum)::date
), material AS (
    SELECT auftrag_id, monat, sum(betrag_netto) AS materialkosten
    FROM kosten
    GROUP BY auftrag_id, monat
)
SELECT u.auftrag_id,
       u.monat,
       u.umsatz_netto,
       coalesce(p.stunden, 0)         AS stunden,
       coalesce(p.personalkosten, 0)  AS personalkosten,
       coalesce(m.materialkosten, 0)  AS materialkosten,
       u.umsatz_netto - coalesce(p.personalkosten, 0) - coalesce(m.materialkosten, 0) AS deckungsbeitrag,
       round(100 * (u.umsatz_netto - coalesce(p.personalkosten, 0) - coalesce(m.materialkosten, 0))
             / nullif(u.umsatz_netto, 0), 1)                                         AS marge_prozent
FROM umsatz u
LEFT JOIN personal p ON p.auftrag_id = u.auftrag_id AND p.monat = u.monat
LEFT JOIN material m ON m.auftrag_id = u.auftrag_id AND m.monat = u.monat;

-- Auslastung je Mitarbeiter und Monat: Ist-Stunden gegen Soll-Stunden
CREATE VIEW v_auslastung_monat AS
SELECT m.mitarbeiter_id,
       m.vorname || ' ' || m.nachname                                        AS mitarbeiter,
       date_trunc('month', e.datum)::date                                    AS monat,
       sum(zt.stunden)                                                       AS ist_stunden,
       round(m.wochenstunden_soll * 52.0 / 12, 1)                            AS soll_stunden,
       round(100 * sum(zt.stunden) / (m.wochenstunden_soll * 52.0 / 12), 1)  AS auslastung_prozent
FROM zeiterfassung zt
JOIN einsatz     e ON e.einsatz_id     = zt.einsatz_id
JOIN mitarbeiter m ON m.mitarbeiter_id = zt.mitarbeiter_id
GROUP BY m.mitarbeiter_id, m.vorname, m.nachname, m.wochenstunden_soll, date_trunc('month', e.datum);
