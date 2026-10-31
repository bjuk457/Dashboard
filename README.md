# Search Console Dashboard für den Mac

Eine kleine Mac-App mit Widgets für den Schreibtisch. Sie zeigt für deine Websites aus der Google Search Console die Klicks, Impressionen, CTR, durchschnittliche Position und die wichtigsten Suchbegriffe, jeweils für die letzten 28 Tage im Vergleich zu den 28 Tagen davor.

## Widgets

- **Alle Websites** (mittel, groß): pro Website Klicks mit Veränderung in % und durchschnittliche Position mit Auf- oder Abwärtstrend.
- **Website** (klein, mittel, groß): eine Website nach Wahl. Klein zeigt die Klicks und den Top-Suchbegriff, mittel zusätzlich Impressionen, CTR, Position und die Top 5 Suchbegriffe, groß die Top 8 Suchbegriffe sowie Gewinner und Verlierer.

Grün heißt besser, rot heißt schlechter. Bei der Position ist kleiner besser, ▲ bedeutet also nach oben gerutscht.

Google stellt die Daten mit etwa 2 bis 3 Tagen Verzögerung bereit. Der Zeitraum endet deshalb 3 Tage vor heute. Die Widgets aktualisieren sich etwa alle 3 Stunden, macOS entscheidet über den genauen Zeitpunkt. In der App selbst gibt es einen Knopf zum sofortigen Aktualisieren.

## Einrichtung

Voraussetzungen: macOS 14 (Sonoma) oder neuer, Xcode 15 oder neuer, [Homebrew](https://brew.sh). Eine normale, kostenlose Apple-ID in Xcode reicht für den Eigengebrauch.

### 1. Google Cloud vorbereiten (einmalig)

1. In der [Google Cloud Console](https://console.cloud.google.com/) ein neues Projekt anlegen, z.B. „Search Console Widget“.
2. Unter **APIs & Dienste → Bibliothek** die **Google Search Console API** aktivieren.
3. Unter **Google Auth Platform → Branding** (früher „OAuth-Zustimmungsbildschirm“) eine App vom Typ **Extern** anlegen.
4. Unter **Zielgruppe** dein Google-Konto als Testnutzer eintragen und danach **App veröffentlichen** („In Produktion“). Im Teststatus läuft die Anmeldung nach 7 Tagen ab. Eine Prüfung durch Google ist für den Eigengebrauch nicht nötig. Bei der Anmeldung erscheint dann der Hinweis „Google hat diese App nicht überprüft“, den du mit **Erweitert → Weiter** bestätigst.
5. Unter **Clients → Client erstellen** den Anwendungstyp **iOS** wählen (das gilt auch für Mac-Apps) und als Bundle-ID `<dein Präfix>.SearchConsoleDashboard` eintragen, z.B. `de.straub.SearchConsoleDashboard`.
6. Die **Client-ID** notieren. Ein Clientschlüssel wird nicht gebraucht.

### 2. App bauen

```sh
brew install xcodegen
git clone https://github.com/bjuk457/Dashboard.git
cd Dashboard
cp Config/Config.example.xcconfig Config/Config.xcconfig
```

In `Config/Config.xcconfig` eintragen:

- `DEVELOPMENT_TEAM`: deine Team-ID aus **Xcode → Einstellungen → Accounts** (bei einer kostenlosen Apple-ID steht dort „Personal Team“).
- `BUNDLE_ID_PREFIX`: dasselbe Präfix wie in Schritt 1.5, z.B. `de.straub`.
- `GOOGLE_CLIENT_ID` und `GOOGLE_REVERSED_CLIENT_ID` aus Schritt 1.6.

Dann:

```sh
xcodegen generate
open SearchConsoleDashboard.xcodeproj
```

In Xcode das Schema **SearchConsoleDashboard** wählen und mit **Product → Run** starten. Für den Dauerbetrieb **Product → Archive → Distribute App → Custom → Copy App** wählen und die App in den Ordner „Programme“ legen.

### 3. Anmelden und Widgets platzieren

1. Die App „Search Console“ öffnen und **Mit Google anmelden** klicken.
2. Mit dem Google-Konto anmelden, das Zugriff auf die Search Console hat.
3. Rechtsklick auf den Schreibtisch → **Widgets bearbeiten** → „Search Console“ suchen und die gewünschten Widgets auf den Schreibtisch ziehen. Beim Widget „Website“ per Rechtsklick → **Widget bearbeiten** die Website auswählen.

Die App muss danach nicht geöffnet bleiben, die Widgets holen sich die Daten selbst.

## Aufbau

| Ordner | Inhalt |
| --- | --- |
| `App/` | Mac-App: Google-Anmeldung und Übersicht aller Websites |
| `Widget/` | Widget-Erweiterung mit den Widgets „Alle Websites“ und „Website“ |
| `Shared/` | Gemeinsamer Code: Google-Anmeldung (OAuth mit PKCE), Search-Console-Abfragen, Speicher |
| `project.yml` | Projektbeschreibung für XcodeGen, daraus entsteht das Xcode-Projekt |

App und Widget teilen sich die Anmeldung und die zuletzt geladenen Zahlen über eine App Group. Die App fragt nur Leserechte für die Search Console an (`webmasters.readonly`).
