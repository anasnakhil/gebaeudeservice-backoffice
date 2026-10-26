-- =====================================================================
-- kpi_abfragen.sql  |  Beispielabfragen für das Reporting
-- Ausführen z. B. mit:
--   docker compose exec postgres psql -U gs_admin -d gebaeudeservice -f /queries/kpi_abfragen.sql
-- (Das Verzeichnis db/queries wird im Container unter /queries eingebunden.)
-- =====================================================================

-- 1) Umsatz pro Monat
SELECT monat, umsatz_netto, anzahl_rechnungen
FROM v_umsatz_monat
ORDER BY monat;

-- 2) Marge pro Auftrag und Monat (mit Kundenname, JOIN über drei Tabellen)
SELECT k.firmenname,
       m.monat,
       m.umsatz_netto,
       m.personalkosten,
       m.materialkosten,
       m.deckungsbeitrag,
       m.marge_prozent
FROM v_marge_auftrag_monat m
JOIN auftrag au ON au.auftrag_id = m.auftrag_id
JOIN angebot an ON an.angebot_id = au.angebot_id
JOIN kunde   k  ON k.kunde_id    = an.kunde_id
ORDER BY m.monat, m.marge_prozent DESC;

-- 3) Auslastung je Mitarbeiter (Ist- gegen Soll-Stunden)
SELECT mitarbeiter, monat, ist_stunden, soll_stunden, auslastung_prozent
FROM v_auslastung_monat
ORDER BY monat, mitarbeiter;

-- 4) Offene Posten, überfällige zuerst
SELECT rechnungsnummer, firmenname, faellig_am, offen, tage_ueberfaellig
FROM v_offene_posten
ORDER BY tage_ueberfaellig DESC;

-- 5) Beanstandungsquote je Auftrag (Qualität)
SELECT au.auftrag_id,
       k.firmenname,
       count(*) FILTER (WHERE e.status = 'durchgefuehrt')                        AS einsaetze,
       count(*) FILTER (WHERE e.qualitaet_ok IS FALSE)                           AS beanstandet,
       round(100.0 * count(*) FILTER (WHERE e.qualitaet_ok IS FALSE)
             / nullif(count(*) FILTER (WHERE e.status = 'durchgefuehrt'), 0), 1) AS quote_prozent
FROM einsatz e
JOIN auftrag au ON au.auftrag_id = e.auftrag_id
JOIN angebot an ON an.angebot_id = au.angebot_id
JOIN kunde   k  ON k.kunde_id    = an.kunde_id
GROUP BY au.auftrag_id, k.firmenname
ORDER BY quote_prozent DESC NULLS LAST;
