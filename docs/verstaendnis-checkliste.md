# Verständnis-Checkliste

Für mich selbst: Zu jedem Baustein sollte ich die Fragen ohne Hilfe beantworten und die Aufgabe lösen können.

## Git und GitHub
- Was ist der Unterschied zwischen einem Commit, einem Branch und einem Pull Request?
- Warum steht `.env` in der `.gitignore`?
- **Aufgabe:** Einen Branch anlegen, die README ändern, mergen.

## SQL und Datenmodell
- Warum gibt es `objekt` als eigene Tabelle und nicht direkt im Kunden?
- Was ist der Unterschied zwischen `INNER JOIN` und `LEFT JOIN`? Wo wird welcher benutzt und warum?
- Was macht `UNIQUE (auftrag_id, datum)`, und was würde ohne passieren?
- Wie berechnet `v_marge_auftrag_monat` den Deckungsbeitrag?
- **Aufgabe:** Eine Abfrage schreiben, die den Umsatz je Kunde und Quartal zeigt.
- **Aufgabe:** Eine neue Leistung (z. B. Fensterreinigung) anlegen und ein Angebot dafür berechnen.

## Docker und Linux
- Was ist der Unterschied zwischen Image und Container?
- Wozu dienen die Volumes `pgdata` und `n8n_data`? Was passiert bei `docker compose down -v`?
- Warum ist der Postgres-Port nur an `127.0.0.1` gebunden?
- Wie lese ich die Logs eines einzelnen Dienstes?
- **Aufgabe:** Einen Dienst absichtlich falsch konfigurieren und den Fehler über die Logs finden.

## Reverse Proxy (Caddy)
- Was macht ein Reverse Proxy, und warum steht er vor n8n?
- Woher bekommt Caddy sein Zertifikat lokal, woher auf einem Server?

## n8n, REST und Webhooks
- Was ist ein Webhook, und was ist der Unterschied zwischen Test- und Produktions-URL?
- Welche Knoten hat der Rechnungs-Workflow, und was liefert jeder an den nächsten?
- Warum rechnet n8n nicht selbst, sondern ruft SQL-Funktionen auf?
- **Aufgabe:** Dem Rechnungs-PDF eine zusätzliche Zeile hinzufügen (z. B. Bankverbindung).

## BPMN
- Welche Elemente kommen im Modell vor (Ereignis, Aufgabe, Gateway)?
- Welche Schritte sind automatisiert, welche manuell?

## Gesamtaufgabe (Selbsttest)
Eine neue Spalte `telefon_ansprechpartner` im Kunden ergänzen und bis in das Rechnungs-PDF durchreichen, ohne Hilfe.
