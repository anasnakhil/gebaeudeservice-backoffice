# Entscheidungen und Vereinfachungen

Kurze Begründungen, warum das Projekt so aufgebaut ist. Jede Entscheidung hat Alternativen, die ich bewusst nicht gewählt habe.

## 1. Fachlogik in SQL-Funktionen, n8n nur als Verbindung

**Entscheidung:** Kalkulation, Einsatzplanung und Rechnungserstellung stehen als Funktionen in PostgreSQL. n8n ruft sie auf und kümmert sich um Webhooks, Zeitpläne und die PDF-Erzeugung.
**Warum:** Die Logik ist dann an einer Stelle, mit einem Selbsttest prüfbar ([`db/tests/smoke_test.sql`](../db/tests/smoke_test.sql)) und nicht an ein einzelnes Werkzeug gebunden. Ein Wechsel von n8n zu etwas anderem würde die Rechenlogik nicht berühren.
**Preis:** Wer SQL-Funktionen nicht kennt, muss sie zuerst lesen können.

## 2. PostgreSQL statt Tabellenkalkulation

**Warum:** Beziehungen (Kunde, Objekt, Auftrag, Einsatz) und Regeln (Fremdschlüssel, CHECK-Constraints) schützen die Datenqualität. Auswertungen wie Marge und Auslastung sind als Views jederzeit reproduzierbar.

## 3. Caddy als Reverse Proxy

**Entscheidung:** Caddy nimmt HTTPS-Anfragen an und leitet sie an n8n weiter.
**Warum:** Zertifikate werden automatisch besorgt und erneuert, die Konfiguration besteht aus wenigen Zeilen. Nginx ist am Markt verbreiteter und könnte dieselbe Aufgabe übernehmen. Das Konzept (Reverse Proxy mit TLS) ist dasselbe.

## 4. Gotenberg für PDFs

**Entscheidung:** Die Rechnung wird als HTML gebaut und von Gotenberg (Chromium in einem Container) in ein PDF umgewandelt.
**Warum:** Kein eigener PDF-Code nötig, und das Layout lässt sich mit HTML und CSS gestalten. Später kann ein Python-Skript dieselbe Aufgabe übernehmen (siehe Roadmap).

## 5. Wiederholbare (idempotente) Abläufe

Planung und Rechnungserstellung können mehrfach laufen, ohne Duplikate zu erzeugen: `ON CONFLICT DO NOTHING` bei Einsätzen, Prüfung auf vorhandene Rechnung bei `erstelle_rechnung()`. Das ist wichtig, wenn ein Workflow aus Versehen zweimal startet.

## Bekannte Vereinfachungen

- **Keine rechtsgültigen Rechnungen:** Die Absenderdaten sind Platzhalter. Vor dem echten Einsatz müssen Pflichtangaben, Steuerfragen und die Archivierung (Aufbewahrungsfristen) geklärt werden.
- **Rechnungsnummern** laufen durchgehend und werden nicht jährlich zurückgesetzt.
- **Kein Mahnwesen** und keine Teilrechnungen.
- **Webhooks ohne Authentifizierung** (nur für lokale Demo geeignet).
- **Preismodell vereinfacht:** Aufwand aus Fläche und Leistungswert, keine Zuschläge, Anfahrt oder Mindestmengen.
