# Dashboard-Widgets für den Mac

Widgets für den Schreibtisch des Mac mit einer kleinen Begleit-App für die Anmeldung. Sie zeigen pro Website:

- aus der **Google Search Console** Klicks, Impressionen, CTR, durchschnittliche Position und die wichtigsten Suchbegriffe,
- von **Instagram und Facebook** (Meta) Follower mit Zuwachs, Reichweite, Aufrufe, Interaktionen und die letzten Beiträge.

Alle Zahlen gelten für die letzten 28 Tage im Vergleich zu den 28 Tagen davor. Die App muss nur zum Anmelden geöffnet werden, die Widgets holen sich die Daten danach selbst.

## Widgets

- **Alle Websites** (mittel, groß): pro Website Klicks mit Veränderung in %, durchschnittliche Position und die Follower auf Instagram und Facebook.
- **Website** (klein, mittel, groß, extragroß): eine Website nach Wahl. Klein zeigt Klicks und Follower, mittel zusätzlich Impressionen, CTR, Position und die Top-Suchbegriffe, groß mehr Suchbegriffe und je eine Karte für Instagram und Facebook, extragroß dazu Gewinner, Verlierer und die letzten Beiträge.
- **Social Media** (klein, mittel, groß): nur Instagram und Facebook einer Website, groß mit den letzten Beiträgen.

Welche Konten zu welcher Website gehören, legst du in der App fest. Vorgesehen ist:

| Website | Instagram | Facebook |
| --- | --- | --- |
| sk-audio.com | ja | ja |
| 3dprotec.com | printhive3d.de | – |
| hochzeitschaos.com | – | – |

Den Follower-Zuwachs liefert Meta nicht direkt. Die Widgets merken sich deshalb die Followerzahl jeden Tag und vergleichen mit dem ältesten Wert der letzten 28 Tage. In den ersten Tagen nach der Einrichtung ist der Zuwachs daher noch klein oder fehlt.

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

### 3. Meta-Zugang einrichten (einmalig)

Für Facebook-Seiten und Instagram-Konten, die mit einer Facebook-Seite verknüpft sind, reicht ein einziger Zugriffsschlüssel eines **Systemnutzers**. Er läuft nicht ab.

1. Auf [developers.facebook.com](https://developers.facebook.com/apps) → **App erstellen**. Als Anwendungsfall **Sonstiges**, als Typ **Business** wählen und die App mit deinem Business-Portfolio verknüpfen. Die App bleibt im Entwicklungsmodus, eine Prüfung durch Meta ist für den Eigengebrauch nicht nötig.
2. In den [Business-Einstellungen](https://business.facebook.com/settings) → **Nutzer → Systemnutzer → Hinzufügen**, Name z.B. „Dashboard“, Rolle **Admin**.
3. Beim Systemnutzer **Assets zuweisen**: die Facebook-Seite von sk-audio, die Instagram-Konten von sk-audio und printhive3d.de sowie die App aus Schritt 1. Lesezugriff auf Inhalte und Statistiken genügt.
4. **Token generieren**: die App wählen, Ablauf **Nie**, und diese Berechtigungen anhaken: `pages_show_list`, `pages_read_engagement`, `read_insights`, `instagram_basic`, `instagram_manage_insights`, `business_management`.
5. Den Schlüssel kopieren. Er wird nur einmal angezeigt.

**Instagram-Konto ohne Facebook-Seite:** Ist ein Instagram-Konto (z.B. printhive3d.de) mit keiner Facebook-Seite verknüpft, erscheint es mit dem Schlüssel oben nicht. Dann in der App aus Schritt 1 das Produkt **Instagram → API-Einrichtung mit Instagram-Login** hinzufügen, das Instagram-Konto dort unter **Zugriffsschlüssel generieren** hinzufügen (es muss ein Business- oder Creator-Konto sein) und mit den Berechtigungen `instagram_business_basic` und `instagram_business_manage_insights` einen Schlüssel erzeugen. Dieser gilt 60 Tage, die Widgets verlängern ihn automatisch, solange sie mindestens einmal pro Woche laufen.

### 4. Anmelden und Widgets platzieren

1. Die App „Dashboard“ öffnen und **Mit Google anmelden** klicken, mit dem Google-Konto, das Zugriff auf die Search Console hat.
2. **Instagram & Facebook** (oder **Dashboard → Einstellungen**) öffnen, den Systemnutzer-Schlüssel einfügen und **Konten laden** klicken. Einen Instagram-Login-Schlüssel fügst du darunter bei **Instagram-Konto einzeln** ein.
3. Darunter prüfen, welche Konten zu welcher Website gehören. Die App schlägt die Zuordnung anhand der Namen vor.
4. Rechtsklick auf den Schreibtisch → **Widgets bearbeiten** → „Dashboard“ suchen und die gewünschten Widgets auf den Schreibtisch ziehen. Bei „Website“ und „Social Media“ per Rechtsklick → **Widget bearbeiten** die Website auswählen.

Die App muss danach nicht geöffnet bleiben, die Widgets holen sich die Daten selbst.

## Aufbau

| Ordner | Inhalt |
| --- | --- |
| `App/` | Mac-App: Google-Anmeldung, Meta-Konten verbinden und zuordnen, Übersicht aller Websites |
| `Widget/` | Widget-Erweiterung mit den Widgets „Alle Websites“, „Website“ und „Social Media“ |
| `Shared/` | Gemeinsamer Code: Google-Anmeldung (OAuth mit PKCE), Search-Console- und Meta-Graph-Abfragen, Speicher |
| `project.yml` | Projektbeschreibung für XcodeGen, daraus entsteht das Xcode-Projekt |

App und Widget teilen sich die Anmeldung und die zuletzt geladenen Zahlen über eine App Group. Die App fragt nur Leserechte für die Search Console an (`webmasters.readonly`). Bei Meta liest sie nur Seiten- und Konto-Statistiken, sie kann nichts veröffentlichen. Die Meta-Zahlen kommen aus der Graph API `v24.0`: Instagram `reach`, `views`, `total_interactions` und `followers_count`, Facebook `page_media_view`, `page_post_engagements`, `page_daily_follows_unique` und `followers_count`. Benennt Meta eine Kennzahl um, fehlt nur diese eine Zeile im Widget.
