# Project Status / Ist-Stand

**Stand:** 2026-08-13
**Phase:** Milestone 4 implementiert; Prompt 4.5 Präsentations-Rebuild und Prompt 4.6 Animations-/UI-Polish implementiert und lokal validiert
**Freigabe:** Spielbarer Windows-Vertical-Slice; keine Release-, Packaging- oder Milestone-5-Freigabe

## Gesamtstand

KoalaPet ist ein Windows-first, local-first Godot-V-Pet. Der aktuelle Vertical Slice umfasst ein aktives Pet, drei Starter-Eier, die klassische Pflege, sechs verzweigte Juvenile-Formen, normale Kämpfe und einen fünfstufigen ersten Dungeon. Minimal, Small und Expanded sind ausschließlich Präsentationen derselben `PetApplication` und derselben versionierten Simulation.

Die verworfene Debug-/Programmer-Art-Präsentation wurde vollständig ersetzt. Der normale Spielerpfad verwendet ein kohärentes dunkles Pixel-UI, einen geschichteten `Quiet Canopy`-Lebensraum, originale provisorische Bildassets und echte achtstufige Lokomotion. Entwicklungssteuerungen sind nur mit `--dev-tools` in einem separaten Fenster verfügbar.

## Implementiert

### Foundation, Content und Saves

- ein versioniertes Registry-/Validator-System für gebündelte und externe JSON-/Safe-Media-Packs
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
- **Small `640×360`:** kompakter Habitat-Desktopmodus mit sechs segmentierten Statuswerten, Care-/Adventure-/More-Kontexten und jeweils drei direkt erreichbaren Hauptaktionen
- **Expanded `1120×720`:** optionale Managementansicht mit Pflegeprotokoll, Habitat, Ereignissen, Battle, Dungeon, Inventar, Codex und Evolution; keine rohe Debug-Form und kein permanenter Vollbildanspruch
- ein gemeinsames Pixel-Theme und wiederverwendbare Komponenten für Panel, Titel, Tabs, Buttons, Status, Call-Bubble, Modal, Starterkarte, Inventar/Kodex, Kampfhaltung, Dungeon-Knoten, Eventlog und Reward-Toast
- Text-Wrapping, Ellipsis, vergrößerte lokalisierbare Inventarkarten, Tastaturfokus, Tooltips und Reduced-Motion-Umschaltung
- versionierte Präsentationsoptionen getrennt vom Spielstand: UI-/Text-/Pet-Skalierung, Dichte, Sprache, Kontrast, Tooltips, Roaming, Animations-/Laufgeschwindigkeit, Effekte, Startmodus und Desktopverhalten
- feste Habitat-Anker für Futter, Leckerli, Bad, Training, Bett, Medizin und Aufbruch; Aktionen laufen zur Station, spielen einmal und kehren in den autoritativen Zustand zurück
- Battle und Dungeon bleiben hinter den vorhandenen datengetriebenen Gates

### Visuelle Assets

- 19 erhaltene Bildquellen für drei Eier, drei Hatchlings, sechs Juveniles, drei normale Gegner, einen Boss, Habitat und UI-Icons
- 128×128 transparente Charakterframes, 64×64 Previews, 96×96 Portraits und 24×24 UI-Icons
- `Quiet Canopy` mit 512×192 Hintergrund, Ground, Schlafplatz, Bad, Futterplatz, Training, Pflanzen, Trophy-Shelf, Laterne, Truhe, Vordergrund und Effekten
- Animationen für Idle/Walk/Eat/Happy/Sleep/Sick/Injured/Training/Attack/Hit/Victory/Call sowie Ei- und Gegnerzustände; alle neun spielbaren Walk-Zyklen besitzen acht sequenzielle Frames bei 10 fps
- Quellen, Prompt, Hashes und Verarbeitung sind erfasst; Art- und Lizenzstatus bleiben ausdrücklich `PROVISIONAL_PRODUCT_REVIEW` / `UNDECIDED`

## Direkte Windows-Evidenz

- privatsichere native Screenshots für Starter, alle Eier/Hatchlings, gute/schlechte Juvenile, Minimal/Small/Expanded, Care-Zustände, Evolution, Battle, Dungeon, Boss und Rewards
- echte Desktopaufnahme bestätigt Minimal ohne opakes Rechteck; native Diagnostik bestätigt transparentes Window/Viewport, Borderless, Always-on-top, No-focus und Hit-Region
- 14-Sekunden-MJPEG-Film mit `84` Frames bei `1040×640`/`6 fps`: Pet läuft transparent, Pet-Klick öffnet Small, Care-Klick, F3 öffnet Expanded, F1 kehrt zu Minimal zurück, Klick außerhalb trifft das darunterliegende Testfenster während KoalaPet weiterläuft
- Reproduktion, Dateihashes und Evidenzgrenzen: [`evidence/visual-rebuild/README.md`](evidence/visual-rebuild/README.md)
- Prompt-4.6-Evidenz: Small/Expanded/Settings/Minimal-/Stationsaufnahmen, neun Walk-GIFs, 23-Sekunden-Polish-Film und sieben Performance-Szenarien unter [`evidence/animation-polish/README.md`](evidence/animation-polish/README.md)

## Validierung

Aktueller vollständiger Lauf mit Godot `4.7.1.stable.official.a13da4feb`:

- Content-, JSON-, Python-Compile-, Markdown-Link-, Mod-Payload-, Neutral-Term-, Repository-Artefakt- und Whitespace-Gates
- Godot Headless Import
- Foundation-Suite
- Pet-Suite einschließlich idempotentem Hatch
- Milestone-4 Evolution/Battle/Dungeon-Suite
- platformneutrale Window-/Placement-Suite
- Präsentations-Suite mit `312` Assertions für Transparenz, UI-Komponenten, State-Revision, achtstufige Lokomotion/Metadaten, Animationspriorität einschließlich veralteter Timer, Preferences-Recovery/Persistenz, Habitat-Anker/Reduced Motion, DE/EN, 100–200%-Bounds, Aktionszugang, Gates und Dev-UI-Isolation
- Asset-Validator für `212` PNGs, Animationsgeometrie und Alpha
- Ruff- und GDLint-Läufe ohne Befund; Python-Abhängigkeiten ohne bekannte Advisories; kein Node-/npm-Abhängigkeitsbaum vorhanden, daher `npm audit` nicht anwendbar

Exakte aktuelle Zählwerte stehen nach dem finalen Gesamtlauf in [`TESTING_AND_QUALITY.md`](TESTING_AND_QUALITY.md) und der Evidenz-README.

## Nicht produktionsreif / Grenzen

- finale Bildrechte und finale Art-Abnahme sind offen; das Generationsmodell meldete keine auslesbare Versionskennung
- Nicht-Lokomotions-Aktionen und Idle bleiben provisorische Zweiframe-Posen; sequentielle Reaktionszyklen und Idle-Varianten sind nicht fertig
- Screenreader- und vollständige manuelle Kontrastabnahme fehlen; Reduced Motion, Fokus und Layout-Gates sind implementiert, aber keine vollständige Accessibility-Zertifizierung
- Taskbar-/Alt+Tab-Sichtbarkeit ist über Godot 4.7 nicht steuerbar; Tray-Menü, Minimize/Restore, Drag, Monitorwechsel und vollständige Mixed-DPI-Matrix sind weiterhin nicht als Produktplattform abgenommen
- ADR 0010 bleibt `proposed`; der erfolgreiche Präsentations-Rebuild akzeptiert die Plattformarchitektur nicht automatisch
- keine Exporte, Signierung, Distribution oder Deployment
- Habitat-Editor, Furniture Placement, Farm, Residents, zweites aktives Pet, Idle Jobs, Trading Post, Economy und Milestone 5 wurden nicht begonnen

## Exakte Empfehlung vor Milestone 5

Milestone 5 noch nicht starten. Zuerst Product-Owner-Abnahme der neuen Bildsprache und aller drei Modi, Entscheidung über Rechte/Lizenz der provisorischen Quellen sowie ein separater Windows-10/11-DPI-/Shell-/Accessibility-Pass. Erst wenn diese drei Gates dokumentiert akzeptiert sind, Milestone 5 `Habitat customization and unlock rewards` freigeben.
