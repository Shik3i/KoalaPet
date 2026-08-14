# Project Status / Ist-Stand

**Stand:** 2026-08-14
**Phase:** Milestone 4 implementiert; Prompt 4.9 UI-/UX-Rettung der Spieleroberfläche implementiert und lokal validiert
**Freigabe:** Spielbarer Windows-Vertical-Slice; keine Release-, Packaging- oder Milestone-5-Freigabe

## Gesamtstand

KoalaPet ist ein Windows-first, local-first Godot-V-Pet. Der aktuelle Vertical Slice umfasst ein aktives Pet, drei Starter-Eier, die klassische Pflege, sechs verzweigte Juvenile-Formen, normale Kämpfe und einen fünfstufigen ersten Dungeon. Minimal, Small und Expanded sind ausschließlich Präsentationen derselben `PetApplication` und derselben versionierten Simulation.

Die verworfene Debug-/Programmer-Art-Präsentation wurde vollständig ersetzt. Der normale Spielerpfad verwendet ein kohärentes dunkles Pixel-UI, einen geschichteten `Quiet Canopy`-Lebensraum, originale provisorische Bildassets und chronologische `4–8`-Frame-Sequenzen für Idle, Pflege, Schlaf, Zustände und Kampf. Entwicklungssteuerungen sind nur mit `--dev-tools` in einem separaten Fenster verfügbar.

## Implementiert

### Foundation, Content und Saves

- ein versioniertes Registry-/Validator-System für gebündelte und externe JSON-/Safe-Media-Packs; maximal `1024` Dateien, `64 MiB` Gesamtgröße und `2 MiB` pro JSON
- stabile namespaced IDs, DE/EN-Lokalisierung und datengetriebene Eier, Formen, Animationen, Evolutionen, Gegner, Belohnungen und Dungeon-Knoten
- deterministische Zeit, Offline-Cap, Save v3, sequentielle Migrationen, Backup/Recovery und Missing-Content-Quarantäne
- transaktionale Commands und Offline-Synchronisation mit Rollback bei Save-Fehlern; Save-Lock plus Fingerprint-Konfliktprüfung gegen konkurrierende Writer
- sichere Ablehnung von Null-/Falschtyp-Pet-Records, Save-Versionen und Command-Werten; 16-MiB-Save-Limit und strukturelle Quarantäne
- kein Account, Netzwerk, Tracking, Cloud-SDK oder ausführbarer Mod-Payload

### Aktueller Gameplay-Vertical-Slice

- drei Starter-Eier mit zeitbasiertem Schlüpfen und einem aktiven Pet
- Sättigung, Stimmung, Energie, Hygiene, Gesundheit, Disziplin, Gewicht, Schlaf, Abfall, Calls, Krankheit, Medizin und Training
- gute und schlechte Pflegepfade für Moss, Ember und Tide; sechs Juvenile-Formen
- deterministische Kämpfe mit Haltungen, Runden, Erfahrung, Drops, Verletzung und Behandlung
- erster Dungeon mit fünf Knoten, Event, Ruhepunkt, Boss, First-clear-/Repeat-Rewards, Codex und gespeicherten Theme-/Trophy-Unlocks

### Rebuild der Präsentation

- **Minimal `240×160`:** nur animiertes Ei/Pet und temporäre Statusblase; vollständig transparenter Viewport; wanderndes Pet; polygonale native Hit-Region; Klick öffnet Small
- **Small `720×480`, frei skalierbar `600×380`–`1280×860`:** Kopfzeile nur mit Identität und Fensterbedienung, vier beschriftete Pflegewerte, kontextuelle Warnhinweise, dominanter Habitat, drei bis vier Hauptaktionen mit Symbol und Text sowie eine beschriftete Fußnavigation
- **Expanded `1160×760`, frei skalierbar `900×620`–`2200×1400`:** drei Spalten mit Pflegeprotokoll, Habitat mit Tabs und einer Kontextspalte, die dem gewählten Tab folgt; keine rohe Debug-Form und kein permanenter Vollbildanspruch
- ein gemeinsames Pixel-Theme und wiederverwendbare Komponenten für Panel, Titel, Tabs, Buttons, Status, Call-Bubble, Modal, Starterkarte, Inventar/Kodex, Kampfhaltung, Dungeon-Knoten, Eventlog und Reward-Toast
- Text-Wrapping, Ellipsis, vergrößerte lokalisierbare Inventarkarten, Tastaturfokus, Tooltips und Reduced-Motion-Umschaltung
- versionierte Präsentationsoptionen getrennt vom Spielstand: UI-/Text-/Pet-Skalierung, Dichte, Sprache, Kontrast, Tooltips, Roaming, Animations-/Laufgeschwindigkeit, Effekte, Startmodus und Desktopverhalten
- feste Habitat-Anker für Futter, Leckerli, Bad, Training, Bett, Medizin und Aufbruch; Aktionen laufen zur Station, spielen einmal und kehren in den autoritativen Zustand zurück
- begrenzte, priorisierte Animationsereignisse mit stabilen IDs, Marker-gesteuerten Effekten, autoritativer Loop-Rückkehr und pausierter Verarbeitung für versteckte Präsentationen
- datengetriebene Umgebungsreaktionen, Cursoraufmerksamkeit, spielerische Minimal-Bewegung sowie getrennte Optionen für Frequenz, Effekte, Treffererschütterung und Trefferaufhellung
- Battle und Dungeon bleiben hinter den vorhandenen datengetriebenen Gates

### Prompt-4.9-Rettung der Spieleroberfläche

- verworfene Small-Informationsarchitektur ersetzt: statt acht gemischter Symbolknöpfe in der Kopfzeile und sechs winziger Segmentanzeigen jetzt Identität plus Fensterbedienung, vier beschriftete Werte mit Symbol, Name, Prozentwert und Zustandswort sowie eigene Bereiche für Aktionen und Navigation
- Gesundheit, Krankheit, Verletzung, Schlaf, Rufe, Kampf, Dungeon und ausstehende Entwicklung sind kontextuelle Hinweise; der dringendste erscheint in der Kopfzeile
- kontextueller Aktionsersatz: Aufwecken ersetzt Schlafen, Medizin und Behandlung ersetzen Reinigen; Abenteuer bleibt bis zum Gate vollständig abwesend
- `UiMetrics` als einzige Quelle für Raster, Schriftgrößen, Bedienhöhen und Symbolgrößen; `HabitatFrame` skaliert den Habitat mit dem Fenster
- jede Befehlsantwort wird über `ActionFeedback` auf einen lokalisierten Satz mit Schweregrad abgebildet; rohe `error_code`- oder `reason`-Texte erreichen die Oberfläche nicht mehr
- Eingabesicherheit: ein autoritativer Befehl gleichzeitig, gleicher Befehl innerhalb von `450 ms` ist eine Absicht, Wiederaufbau ist nicht wieder eintretbar, Statusmeldungen sind klickdurchlässig
- neun fehlende Symbole deterministisch erzeugt; Fehlzuordnungen wie `close` auf das Verletzungspflaster beseitigt; scharfe 2×-Zwillinge für große Aktionsknöpfe
- Small und Expanded sind echt größenveränderbar mit gemerkter Größe je Modus; `auto`-UI-Skalierung folgt jetzt der Anzeige-DPI statt der auf Windows konstanten `screen_get_scale()`

### Visuelle Assets

- 19 erhaltene Bildquellen für drei Eier, drei Hatchlings, sechs Juveniles, drei normale Gegner, einen Boss, Habitat und UI-Icons
- 128×128 transparente Charakterframes, 64×64 Previews, 96×96 Portraits und 24×24 UI-Icons
- `Quiet Canopy` mit 512×192 Hintergrund, Ground, Schlafplatz, Bad, Futterplatz, Training, Pflanzen, Trophy-Shelf, Laterne, Truhe, Vordergrund und Effekten
- je `29` Animationen mit `4–8` Frames für alle neun spielbaren Formen; je fünf Reaktions-/Kampfanimationen für drei normale Gegner und den Boss; genaue Matrix in [`ANIMATION_COVERAGE.md`](ANIMATION_COVERAGE.md)
- zwölf getrennte familienbezogene VFX-Sequenzen für Moss, Ember und Tide; Marker, Intensität und Reaktionsfeedback bleiben reine Präsentation
- Quellen, Prompt, Hashes und Verarbeitung sind erfasst; Art- und Lizenzstatus bleiben ausdrücklich `PROVISIONAL_PRODUCT_REVIEW` / `UNDECIDED`

## Direkte Windows-Evidenz

- privatsichere native Screenshots für Starter, alle Eier/Hatchlings, gute/schlechte Juvenile, Minimal/Small/Expanded, Care-Zustände, Evolution, Battle, Dungeon, Boss und Rewards
- echte Desktopaufnahme bestätigt Minimal ohne opakes Rechteck; native Diagnostik bestätigt transparentes Window/Viewport, Borderless, Always-on-top, No-focus und Hit-Region
- 14-Sekunden-MJPEG-Film mit `84` Frames bei `1040×640`/`6 fps`: Pet läuft transparent, Pet-Klick öffnet Small, Care-Klick, F3 öffnet Expanded, F1 kehrt zu Minimal zurück, Klick außerhalb trifft das darunterliegende Testfenster während KoalaPet weiterläuft
- Reproduktion, Dateihashes und Evidenzgrenzen: [`evidence/visual-rebuild/README.md`](evidence/visual-rebuild/README.md)
- Prompt-4.6-Evidenz: Small/Expanded/Settings/Minimal-/Stationsaufnahmen, neun Walk-GIFs, 23-Sekunden-Polish-Film und sieben Performance-Szenarien unter [`evidence/animation-polish/README.md`](evidence/animation-polish/README.md)
- Prompt-4.7-Evidenz: sieben native Godot-Movies, zehn extrahierte Belegframes, vollständige/dichte Kontaktbögen, vier Reels und acht Performance-Szenarien unter [`evidence/living-animation/README.md`](evidence/living-animation/README.md)
- Prompt-4.9-Evidenz: 24 native Szenarien über die eigene Viewport-Rückgabe der Anwendung, vollständige Laufzeitdiagnostik je Aufnahme und eine interaktive Aktionsmatrix mit echten Win32-Eingaben unter [`evidence/ui-rescue/README.md`](evidence/ui-rescue/README.md)
- Prompt-4.8-Evidenz: debug-only Runtime-Showroom, `290` klassifizierte Sequenzen, neun Form-Kontaktbögen, vier fokussierte Reels, Rechte-/Optimierungsregister und direkte Windows-Showroom-/Fokusaufnahmen unter [`evidence/visual-acceptance/README.md`](evidence/visual-acceptance/README.md)

## Validierung

Aktueller vollständiger Lauf mit Godot `4.7.1.stable.official.a13da4feb`:

- Content-, JSON-, Python-Compile-, Markdown-Link-, Mod-Payload-, Neutral-Term-, Repository-Artefakt- und Whitespace-Gates
- Godot Headless Import
- Foundation-Suite mit `114` Assertions
- Pet-Suite mit `44` Assertions einschließlich idempotentem Hatch
- Milestone-4 Evolution/Battle/Dungeon-Suite mit `62` Assertions
- platformneutrale Window-/Placement-Suite mit `46` Assertions
- Präsentations-Suite mit `4976` Assertions einschließlich `16` Showroom-Entities, `290` Runtime-Sequenzen, vollständigem Playback, Markerreihenfolge, No-Fallback, Refresh-Stabilität, Reduced Motion, UI-Komponenten, echten Player-UI-Signalpfaden für Füttern/Pflege/Tabs/Modus/Kampf/Einstellungen, vollständiger Deferred-Connection-Prüfung, Preferences, Habitat/Minimal, DE/EN und 100–200%-Layoutgrenzen
- Asset-Validator für `373` PNGs (`372` mit Transparenz), vollständige Animationsabdeckung, Geometrie, Alpha, Chronologie, VFX und Evidenz
- Content-Validator für zwei Packs und `86` JSON-Dokumente
- Ruff- und GDLint-Läufe ohne Befund; Python-Abhängigkeiten ohne bekannte Advisories; kein Node-/npm-Abhängigkeitsbaum vorhanden, daher `npm audit` nicht anwendbar

Exakte aktuelle Zählwerte stehen nach dem finalen Gesamtlauf in [`TESTING_AND_QUALITY.md`](TESTING_AND_QUALITY.md) und der Evidenz-README.

## Prompt 4.9: gemeldeter Feed-Absturz

Der gemeldete sofortige Absturz beim Klick auf Füttern war trotz gezielter Reproduktion nicht nachstellbar: echte Win32-Klicks gegen sauberen Spielstand, den echten Milestone-4-Spielstand des Product Owners (kopiert, nie verändert), Frischling, hungriges, sattes, schlafendes, krankes und verletztes Pet, aktiven Kampf, Small und Expanded, Einzel- und Doppelklicks sowie 25-Klick-Salven beendeten den Prozess kein einziges Mal, und keine Godot-Fehlermeldung wurde protokolliert. Das Godot-Log mit dem ursprünglichen Stack-Trace war bereits rotiert. Eine Ursache für genau diesen Vorfall wird daher **nicht** behauptet.

Auf dem Füttern-Pfad wurden stattdessen vier reale Defekte gefunden, behoben und regressionsgetestet: rohe Engine-Texte in der Statusanzeige, doppelte Befehlsübermittlung bei einem Doppelklick, ein wieder eintretbarer Oberflächen-Wiederaufbau und eine klickblockierende Statusmeldung. Details: [`prompts/PROMPT_0049_UI_RESCUE.md`](prompts/PROMPT_0049_UI_RESCUE.md).

## Nicht produktionsreif / Grenzen

- finale Bildrechte und finale Art-Abnahme sind offen; das Generationsmodell meldete keine auslesbare Versionskennung
- alle neuen Sequenzen bleiben deterministisch abgeleitete, provisorische Produktreview-Art; handfinalisierte Produktionsanimation und formale Rechtefreigabe fehlen
- Windows-Accessibility-Tree-Inspektion fand keine nutzbaren Namen/Child-Nodes für Godot-Controls; sichtbarer Tastaturfokus, Reduced Motion und Layout-Gates sind implementiert, aber Screenreader-Abnahme und formale Compliance fehlen
- Alt+Tab sowie Minimize/Restore waren im interaktiven Debug-Lauf stabil; Tray-Menü/Callbacks/Cleanup, Show Desktop, Hide/Show-Recovery, kontrollierter Monitorwechsel und vollständige Mixed-DPI-Matrix bleiben nicht abgenommen
- ADR 0010 bleibt `proposed`; der erfolgreiche Präsentations-Rebuild akzeptiert die Plattformarchitektur nicht automatisch
- der gemeldete Feed-Absturz ist nicht reproduziert; nur die dabei gefundenen Defekte sind behoben
- die interaktive Aktionsmatrix ist auf diesem Mixed-DPI-Mehrmonitor-Host teilweise durch Koordinaten-Virtualisierung begrenzt; betroffene Bedienelemente wurden koordinatenfrei per Tastaturfokus nachgewiesen
- für Prompt 4.9 wurde kein Video aufgenommen und keine Performance-Neumessung gegen die Prompt-4.7-Basis durchgeführt
- keine Exporte, Signierung, Distribution oder Deployment
- Habitat-Editor, Furniture Placement, Farm, Residents, zweites aktives Pet, Idle Jobs, Trading Post, Economy und Milestone 5 wurden nicht begonnen

## Exakte Empfehlung vor Milestone 5

Milestone 5 noch nicht starten. Zuerst Product-Owner-Abnahme anhand des Prompt-4.8-Reviewpakets, Entscheidung über Rechte/Lizenz der `388` provisorischen Runtime-PNGs sowie Auflösung des Screenreader-Blockers und der fehlenden nativen DPI-/Tray-/Mixed-DPI-Zeilen. Erst wenn diese Gates dokumentiert akzeptiert sind, Milestone 5 `Habitat customization and unlock rewards` freigeben.
