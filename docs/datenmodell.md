# Datenmodell

Das Schema liegt in [`db/init/01_schema.sql`](../db/init/01_schema.sql). Die Struktur folgt dem Geschäftsablauf: Ein Kunde hat Objekte, für ein Objekt gibt es Angebote, ein angenommenes Angebot wird zum Auftrag, daraus entstehen Einsätze, deren Zeiten die Grundlage für Rechnung und Kennzahlen sind.

```mermaid
erDiagram
    kunde ||--o{ objekt : hat
    kunde ||--o{ angebot : erhaelt
    objekt ||--o{ angebot : betrifft
    leistung ||--o{ angebot : "basiert auf"
    angebot ||--o| auftrag : "wird zu"
    auftrag ||--o{ einsatz : plant
    auftrag ||--o{ kosten : verursacht
    auftrag ||--o{ rechnung : "wird abgerechnet in"
    mitarbeiter ||--o{ einsatz : "führt aus"
    einsatz ||--o{ zeiterfassung : erfasst
    mitarbeiter ||--o{ zeiterfassung : leistet
    rechnung ||--|{ rechnung_position : enthaelt
    rechnung ||--o{ zahlung : "wird beglichen durch"

    kunde {
        int kunde_id PK
        text firmenname
        int zahlungsziel_tage
    }
    objekt {
        int objekt_id PK
        int kunde_id FK
        numeric flaeche_qm
        text objektart
    }
    leistung {
        int leistung_id PK
        numeric leistungswert_qm_pro_h
        numeric stundensatz_netto
    }
    angebot {
        int angebot_id PK
        int einsaetze_pro_woche
        numeric preis_pro_einsatz_netto
        text status
    }
    auftrag {
        int auftrag_id PK
        int angebot_id FK
        smallint_array wochentage
        text status
    }
    einsatz {
        int einsatz_id PK
        date datum
        numeric geplant_h
        text status
        boolean qualitaet_ok
    }
    zeiterfassung {
        int zeit_id PK
        numeric stunden
    }
    rechnung {
        int rechnung_id PK
        text rechnungsnummer
        date leistungsmonat
        text status
    }
```

## Wichtige Regeln im Schema

- **Primärschlüssel** sind `GENERATED ALWAYS AS IDENTITY`, damit sie nicht von Hand vergeben werden.
- **Fremdschlüssel** sichern, dass es keine Einsätze ohne Auftrag oder Rechnungen ohne Auftrag gibt.
- **CHECK-Constraints** verhindern unsinnige Werte (negative Flächen, Postleitzahlen ohne 5 Ziffern, ungültige Status).
- **`UNIQUE (auftrag_id, datum)`** auf `einsatz`: Ein Auftrag kann pro Tag nur einmal geplant werden. Dadurch ist die Planung wiederholbar, ohne Duplikate zu erzeugen.
- **`UNIQUE (auftrag_id, leistungsmonat)`** auf `rechnung`: Pro Auftrag und Monat gibt es nur eine Rechnung.
- **Rechnungsbeträge werden nicht gespeichert**, sondern in der View `v_rechnung_summe` aus den Positionen berechnet. So kann es keine Abweichung zwischen Positionen und Summe geben.

## Kennzahlen

| View | Frage, die sie beantwortet |
|---|---|
| `v_umsatz_monat` | Wie viel Umsatz habe ich pro Monat gemacht? |
| `v_marge_auftrag_monat` | Welcher Auftrag bringt wie viel Deckungsbeitrag und Marge? |
| `v_auslastung_monat` | Wie stark sind meine Mitarbeiter ausgelastet? |
| `v_offene_posten` | Wer schuldet mir noch Geld, und wie lange schon? |
