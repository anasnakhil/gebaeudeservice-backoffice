-- =====================================================================
-- smoke_test.sql  |  Kleiner Selbsttest der Geschäftslogik
-- Ausführen nach dem ersten Start:
--   docker compose exec postgres psql -U gs_admin -d gebaeudeservice -f /tests/smoke_test.sql
-- Bei einem Fehler bricht das Skript mit einer Meldung ab.
-- =====================================================================

DO $$
DECLARE
    v_preis  numeric;
    v_aufw   numeric;
    v_monat  numeric;
    v_anzahl integer;
BEGIN
    -- Angebot: 220 qm Büro, 3x pro Woche
    --   Aufwand = 220 / 150 = 1,47 h -> auf Viertelstunden gerundet 1,50 h
    --   Preis je Einsatz = 1,50 h * 34,00 EUR = 51,00 EUR
    --   Monatspreis = 51,00 * 3 * 52 / 12 = 663,00 EUR
    SELECT aufwand_h_pro_einsatz, preis_pro_einsatz_netto, preis_pro_monat_netto
      INTO v_aufw, v_preis, v_monat
      FROM berechne_angebot(220, 1, 3::smallint);
    ASSERT v_aufw  = 1.50,   'Aufwand falsch: ' || v_aufw;
    ASSERT v_preis = 51.00,  'Preis je Einsatz falsch: ' || v_preis;
    ASSERT v_monat = 663.00, 'Monatspreis falsch: ' || v_monat;

    -- Planung ist idempotent: zweiter Lauf legt nichts Neues an
    v_anzahl := plane_einsaetze(date '2026-09-01', date '2026-10-31');
    ASSERT v_anzahl = 0, 'Planung nicht idempotent, neu angelegt: ' || v_anzahl;

    -- Rechnung ist idempotent: gleiche ID beim zweiten Aufruf
    ASSERT erstelle_rechnung(1, date '2026-09-01') = erstelle_rechnung(1, date '2026-09-15'),
           'erstelle_rechnung ist nicht idempotent';

    -- Ohne durchgeführte Einsätze darf keine Rechnung entstehen (Dezember 2026)
    BEGIN
        PERFORM erstelle_rechnung(1, date '2026-12-01');
        RAISE EXCEPTION 'Erwartete eine Fehlermeldung für Monat ohne Einsätze';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM NOT LIKE 'Keine durchgeführten Einsätze%' THEN
            RAISE;
        END IF;
    END;

    -- Summen: Brutto = Netto + USt
    ASSERT (SELECT bool_and(brutto = netto + ust) FROM v_rechnung_summe), 'Brutto <> Netto + USt';

    RAISE NOTICE 'Alle Tests bestanden.';
END;
$$;
