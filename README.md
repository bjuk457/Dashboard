# Dashboard-Integrationen für Home Assistant

Eigene Home-Assistant-Integrationen für das Dashboard. Aktuell enthalten:

- **Google Search Console** (`custom_components/search_console`): Klicks, Impressionen, CTR, durchschnittliche Position und die wichtigsten Suchbegriffe je Website, jeweils verglichen mit dem Vorzeitraum.

## Was die Search-Console-Integration liefert

Pro Website entsteht ein Gerät mit fünf Sensoren:

| Sensor | Inhalt |
| --- | --- |
| Klicks | Klicks der letzten 28 Tage, Attribute `previous`, `change`, `change_percent` |
| Impressionen | wie oben |
| CTR | Klickrate in % |
| Durchschnittliche Position | durchschnittliche Position in der Google-Suche (kleiner ist besser) |
| Top-Suchbegriff | Zustand ist der Suchbegriff mit den meisten Klicks. Attribute: `queries` (Top 25), `winners` und `losers` (je 5 Begriffe mit dem größten Klick-Plus bzw. -Minus) |

Jeder Suchbegriff in den Attributen hat `query`, `clicks`, `impressions`, `ctr`, `position`, `clicks_change` und `position_change` (positiv heißt: weiter nach oben gerutscht).

Google stellt die Daten mit etwa 2 bis 3 Tagen Verzögerung bereit. Der Zeitraum endet deshalb immer 3 Tage vor heute (Attribute `start_date` und `end_date`). Abgefragt wird alle 6 Stunden.

## Einrichtung

### 1. Google Cloud vorbereiten (einmalig)

1. In der [Google Cloud Console](https://console.cloud.google.com/) ein neues Projekt anlegen, z.B. „Home Assistant“.
2. Unter **APIs & Dienste → Bibliothek** die **Google Search Console API** aktivieren.
3. Unter **APIs & Dienste → OAuth-Zustimmungsbildschirm** (bzw. **Google Auth Platform**) eine App vom Typ **Extern** anlegen, dein Google-Konto als Testnutzer eintragen.
4. Den Veröffentlichungsstatus auf **In Produktion** stellen. Im Status „Test“ läuft die Anmeldung nach 7 Tagen ab. Eine Prüfung durch Google ist für den Eigengebrauch nicht nötig, bei der Anmeldung erscheint dann nur ein Hinweis „Google hat diese App nicht überprüft“, den du mit **Erweitert → Weiter** bestätigst.
5. Unter **APIs & Dienste → Anmeldedaten → Anmeldedaten erstellen → OAuth-Client-ID** einen Client vom Typ **Webanwendung** anlegen und als autorisierte Weiterleitungs-URI eintragen:
   `https://my.home-assistant.io/redirect/oauth`
6. Client-ID und Clientschlüssel notieren.

### 2. Integration über HACS installieren

1. In Home Assistant **HACS → ⋮ → Benutzerdefinierte Repositories** öffnen.
2. Repository `https://github.com/bjuk457/Dashboard`, Typ **Integration**, hinzufügen.
3. „Google Search Console“ in HACS herunterladen und Home Assistant neu starten.

### 3. Integration hinzufügen

1. **Einstellungen → Geräte & Dienste → Integration hinzufügen → Google Search Console**.
2. Client-ID und Clientschlüssel aus Schritt 1 eintragen.
3. Mit dem Google-Konto anmelden, das Zugriff auf die Search Console hat.
4. Die Websites auswählen. Später lässt sich die Auswahl über **Konfigurieren** ändern.

## Dashboard-Karte

Beispiel für eine Markdown-Karte mit den Top-Suchbegriffen einer Website. Die Entitäts-ID findest du auf der Geräteseite der Website.

```yaml
type: markdown
title: sk-audio.com
content: |
  {% set s = 'sensor.www_sk_audio_com_top_suchbegriff' %}
  **{{ states('sensor.www_sk_audio_com_klicks') }} Klicks** ·
  Ø Position {{ states('sensor.www_sk_audio_com_durchschnittliche_position') }}

  | Suchbegriff | Klicks | Pos. |
  |:--|--:|--:|
  {% for q in (state_attr(s, 'queries') or [])[:10] -%}
  | {{ q.query }} | {{ q.clicks }} ({{ '%+d' % q.clicks_change }}) | {{ q.position }} |
  {% endfor %}
```
