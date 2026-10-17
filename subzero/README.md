# SUB-ZERO: THE HEAT HUNTER

Kooperativer Survival-Horror für Roblox (1 bis 4 Spieler, 12 bis 18 Minuten pro Runde), komplett nach der
*Master-Spezifikation v2* gebaut – alle 10 Etappen in einem Schritt.

Ihr steigt in die Forschungsstation **Erebos** ab, löst vier Zonen und entkommt per Helikopter.
Ein Wesen jagt euch, das **Wärme und Geräusche** wahrnimmt, aber nichts sieht:
Wer warm ist, lebt länger, ist aber gut sichtbar. Wer kalt ist, ist fast unsichtbar, stirbt aber an Unterkühlung.

---

## Schnellstart

1. **`build/SubZero.rbxl`** in Roblox Studio öffnen (Datei → Öffnen). Die komplette Map ist bereits eingebaut.
2. **Testen:** Reiter *Test* → *Play* (F5) für Solo, oder *Start* mit 2–4 *Clients* + *Server* für Koop.
3. Einmalig in den **Game Settings** (nach dem Veröffentlichen):
   - *Security → Enable Studio Access to API Services* einschalten (sonst werden Statistiken und Bestenlisten nur im Speicher gehalten – das Spiel läuft trotzdem).
   - *Places → Max Players = 6* (Server-Größe laut Abschnitt 12; zusätzlich kickt der Server den 7. Spieler).
   - Avatar-Typ ist in der Datei bereits auf **R15** gesetzt.

In der Lobby: Ausrüstung am **EQUIPMENT**-Spind wählen, am Notfall-Hebel **E** (Glas zerbricht), dann **E 1,5 s halten**
(Hebel), und innerhalb von 10 s in die **gelb markierte Schleuse** stellen.

## Steuerung

| Aktion | PC | Gamepad | Handy |
|---|---|---|---|
| Liegen umschalten (hält automatisch den Atem an) | Z | Y | Knopf *LIE* |
| Ducken umschalten | C | B | Knopf *DUCK* |
| Sprinten (halten) | Shift | L3 | Knopf *RUN* |
| Item benutzen (Fackel zünden, Handwärmer, Injektor, Batterie) | Linksklick | R2 | Knopf *USE* |
| Fackel werfen (ca. 40 Studs) | G | R1 | Knopf *THROW* |
| Taschenlampe an/aus | F | DPad hoch | Knopf *LAMP* |
| Wärmebild-Scanner | Rechtsklick | L2 | Knopf *SCAN* |
| Gürtel-Slot wählen | 1–4 / Mausrad | DPad links/rechts | – |
| Fallenlassen | Backspace | DPad runter | – |
| Interagieren (Aufheben, Spind, Kurbeln, Wiederbeleben …) | E (halten, wo nötig) | X | Fenster antippen |
| Notiz/Terminal schließen | E | B | X-Knopf |
| Einstellungen | P | Start | Knopf *SET* |
| Zuschauer: Spieler wechseln | Links-/Rechtsklick | DPad | USE/SCAN |

## Was enthalten ist (Abschnitt → Umsetzung)

| Spezifikation | Umsetzung |
|---|---|
| 1 Spielübersicht | Sieg/Niederlage, Kollaps, Tod, Zuschauer – `RoundService`, `HealthService` |
| 3 Temperatur & Wärmesignatur | Formel 3.1 und 3.3 exakt, 5 Hz, Attribute `BodyTemp`, `HeatSig`, `HypoStage` – `TemperatureService` |
| 4 Bewegung, Stamina, Atem, Herzfrequenz, Kollaps | Haltungen mit 0,4 s/0,6 s Übergang, Sprint 12/s, Atem 10 s/6 s, BPM-Formel, Wiederbelebung 4 s (max. 2×) – `MovementService`, `TemperatureService`, `HealthService` |
| 4.3 Versteck-Spinde | 12 Spinde, Signatur ×0,2, Lamellen-Sicht, Wesen reißt sie bei Aufmerksamkeit > 70 auf |
| 5 Das Wesen | Wärme-Strahl 360° (ThermalBlock), Gehör (halber Radius durch Wände), Leuchtfeuer, Aufmerksamkeit pro Spieler, alle 8 Zustände, Pfadfindung, Türen aufbrechen (2,5 s), Lüftungsschacht-Netz (13 Schächte, Kratzen + Frost), Spannungs-Regisseur, Skalierung nach Spielerzahl – `EntityService` |
| 6 Ausrüstung | 1 Kleidungs- + 4 Gürtel-Slots, alle 10 Items mit Wirkung und Nachteil, Spind-Auswahl – `InventoryService` |
| 7 Zonen & Rätsel | Lobby, Habitation, Bio-Labore, Cargo Bay, Reaktor, Landeplatz – alle Rätsel mit Zufallselementen – `PuzzleService`, `src/mapbuilder` |
| 8 Ablauf | Countdown, CRT-Übergang, Stromausfall bei Minute 4 oder Türöffnung, Phasen, Rückkehr nach 20 s |
| 9 HUD | Frost-Overlay + Unschärfe, analoges Zifferblatt + LED-Leiste, EKG-Oszilloskop, Stamina, Lungen-Ring, Leder-Gürtel mit Feder-Physik (300/20), eigene CRT-Prompts mit Halte-Ring, Notiz-Leser, CRT-Terminals, Einstellungen |
| 10 Kamera, Animation, Effekte, Licht | Erste Person fest, Viewmodel mit Feder, Wackeln, FOV ±1,5°, Kill-Kinematik, prozedurale Posen + IKControl, Atemdampf, Aura, Frost-Spuren (Pool 40), Fackeln, Schneesturm, Licht-Presets je Zone (1,5 s) |
| 11 Sound | SoundGroups, Hall je Zone, Schritte je Untergrund, Biometrie, Infraschall mit Equalizer, Musik, Pool max. 30 |
| 12 Architektur | Exakt die Ordner/Services/Controller aus der Spezifikation, `--!strict`, Attribute statt Dauer-Remotes, Server prüft jede Anfrage, DataStore `PlayerStats_v1` mit 3 Wiederholungen, OrderedDataStore-Bestenlisten |
| 13 Assets & Leistung | Map-Ordner `Map/Zone0..Zone4`, `Map/Helipad` mit Geometry/Props/Lights/Waypoints/Volumes/Spawns, Streaming 256, Schattenlicht-Pool 6, Partikel nur in 80 Studs, Pools |

**Alle Zahlen** (Tempo, Radien, Temperaturen, Zeiten, Licht-Presets, Sound-IDs …) stehen in
`ReplicatedStorage/Shared/Config` (Datei `src/shared/Config.luau`) – Balancing ohne Code-Suche (Regel 1).

## Was ich ersetzt habe (Regel 3: „Wenn Roblox etwas nicht kann …“)

- **Meshes & Texturen:** Ich kann hier keine Meshes/Bilder erzeugen oder hochladen. Map, Hero-Props, Items und das Wesen sind
  aus Teilen mit echten Roblox-Materialien gebaut (kein Plastic/SmoothPlastic). Alle Modelle tragen daher **`_PH`**
  (Regel 4). Jedes Teil hat ein Attribut `MaterialKit` (RustSteel, SaltConcrete, FrostMetal, IceSheet, GrateMetal):
  Legst du im MaterialService MaterialVariants mit genau diesen Namen an, setzt der Server sie beim Start automatisch.
- **Animationen aus dem Animation Editor** (Frieren, Liegen): prozedural über Motor6D + IKControl (`PoseController`).
- **Wesen als Skinned Mesh:** Teile mit Motor6D, prozedural animiert (Zuckungen, Pendeln, Kopf tastet).
- **Lastenaufzug:** Fahrt als Rumpeln + Überblendung + Teleport (bewegte Plattformen mit Spielern sind in Roblox unzuverlässig).
- **CRT-Shader, Frost-Vignette, Riss-Bild, Zifferblatt, Leder-Tasche, Monitor-Rahmen:** Platzhalter aus UI-Frames/Verläufen.
  Trägst du in `Config.Images` Asset-IDs ein, werden echte Bilder verwendet.
- **Frost-Fußabdrücke:** dünne Eis-Teile aus einem 40er-Pool statt Decals (brauchen keine Textur-ID).
- **Fackel-Pool, Item-Pool, Sound-Pool:** vorab erzeugt, in der Runde wird nichts neu gebaut.

## Eigene Verbesserungen (Regel „Autonomie“)

- Story: 12 Notizen/Tonbänder zu Projekt THERMOPHAGE (Lobby + Zonen), Fund wird gespeichert (`LogsFound`).
- Schritte beim Gehen/Ducken erhöhen die Aufmerksamkeit um 6/3 (das Dokument nennt nur Sprint = 10).
- Spieler kollidieren nicht miteinander (enge Flure, Koop), das Wesen läuft durch Spieler hindurch – Fangen geht über Distanz.
- Tempo-Prüfung (Anti-Cheat), Server validiert Entfernungen, Items, Abklingzeiten.
- Verzögerte Abläufe (Schacht-Reise, Tür aufbrechen, Aufzug) brechen beim Rundenende sauber ab.

## Was ich von dir brauche

Das Spiel läuft komplett, aber **stumm**, solange keine Sound-IDs eingetragen sind (nur Schritte und Tropfen nutzen
eingebaute Roblox-Sounds). Bitte in `Config.Sounds` frei nutzbare Audio-IDs aus dem Creator Store eintragen
(`"rbxassetid://123…"`), mindestens:

- Wesen: `Infrasound` (tiefes Brummen, loop), `HuntScreech`, `MetalScreech`, `TuningFork`, `EntityStep`, `VentScratch`, `DoorBang`
- Biometrie: `Heartbeat` (loop), `TeethChatter` (loop), `ShiverBreath` (loop), `Pant`, `Gasp`
- Welt: `Wind` (loop), `GeneratorRun` (loop), `GeneratorStutter`, `Alarm`, `ArmorDoor`, `CentrifugeHum`, `ElevatorRumble`, `Hiss`, `GlassBreak`, `Clink`, `FlareBurn`, `RadiatorCrank`, `ScannerPing`, `EkgBeep`, `Helicopter`, `IceCrack`
- Schritte (je 4 Varianten): `StepGrate`, `StepSnow`, `StepConcrete`, `StepIce`, `StepMetal`
- Musik: `HuntPulse`, `ExtractionDrone`

Optional: Bild-IDs in `Config.Images`, MaterialVariants (siehe oben), eigene Meshes für die `_PH`-Modelle.

## Entwicklung (optional, mit Rojo)

```
src/shared       → ReplicatedStorage/Shared   (Config, Types, Signal, Trove, Spring, ObjectPool, Zones, …)
src/server       → ServerScriptService         (ServerMain, Services/*, Creature)
src/client       → StarterPlayerScripts        (ClientMain, Controllers/*, Lib/*)
src/mapbuilder   → ServerStorage/MapBuilder    (Bau-Kit, Props, Lobby, Zone1–4, Helipad)
tools/build.sh   → baut build/SubZero.rbxl (Rojo + Map-Bake mit Lune)
tools/check.sh   → Typprüfung aller Skripte (luau-lsp, --!strict, Roblox-API)
```

- Bauen: `tools/build.sh` (braucht [Rojo](https://rojo.space) und [Lune](https://lune-org.github.io/docs)).
- Prüfen: `LUAU_LSP=… ROBLOX_DEFS=globalTypes.d.luau tools/check.sh`.
- Live-Sync: `rojo serve` + Rojo-Plugin. Fehlt `Workspace.Map`, baut der Server die Map beim Start selbst.

## Prüfstand

Roblox Studio selbst konnte ich in meiner Umgebung nicht starten. Geprüft wurde:

- **Typprüfung:** alle Skripte mit luau-lsp im `--!strict`-Modus gegen die aktuelle Roblox-API – **0 Fehler, 0 Warnungen**.
- **Map:** 3560 Teile gebaut; automatischer Abgleich, dass jeder Tag und jedes benannte Teil, das der Code sucht, existiert
  (0 Fehler); Draufsicht-Renderings jeder Zone auf Überlappungen und Fehlplatzierungen kontrolliert.
- **Place-Datei:** Inhalt (Skripte, Remotes, Einstellungen, Licht, SoundGroups) nach dem Bau verifiziert.

Was noch aussteht, ist der echte Play-Test in Studio (Regel 5). Falls in der Ausgabe-Konsole etwas Rotes erscheint,
schick mir den Text – ich behebe es sofort.
