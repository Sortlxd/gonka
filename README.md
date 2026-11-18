# gonka 🚗

**Ein 3D-Idle-Rennspiel für Smartphones, entwickelt mit Godot 4 und GDScript.**
*A 3D idle driving game for mobile, made with Godot 4 and GDScript (English below).*

> 🚧 Work in progress – das Spiel ist noch in Entwicklung.

<!-- Screenshots: lege Bilder in einen Ordner "screenshots" und entferne die Kommentarzeichen
![Fahren](screenshots/drive.png) ![Garage](screenshots/garage.png) ![Rennen](screenshots/race.png)
-->

## Über das Spiel

Dein Auto fährt automatisch eine endlose Straße entlang – jeder gefahrene Kilometer ist die Währung (**KM**). Mit den KM kaufst du Upgrades, neue Autos und Lackierungen. Langsamer Verkehr bremst dich aus: Mit der Überhol-Taste startest du ein Reaktions-Minispiel. Triffst du die grüne Zone mehrmals, überholst du erfolgreich – sonst gibt es einen Unfall und du verlierst einen Teil deines Guthabens.

## Features

- **3D-Welt im Hochformat** mit endloser Straße, Gegenverkehr und wechselnden Biomen (z. B. Wiesen, Berge)
- **Tag-und-Nacht-Zyklus und Wetter** – Regen, Wolken, Nebel, Scheinwerfer mit Lichtkegeln in der Nacht
- **Überhol-Minispiel** mit mehreren Stufen und Unfall-Strafe
- **Boss-Rennen**: Nach einem Überholmanöver kann ein Rennen gegen einen Boss starten – vier Seltenheitsstufen (Common bis Legendary) mit steigender Belohnung
- **Garage & Tuning**: mehrere Autos, Tuning von Motor, Getriebe, Rädern und Turbo, Lackierungen, Showroom
- **Exklusive Autos**, die aus Teilen aus vier Arten von Kisten zusammengebaut werden
- **Offline-Einnahmen**, Werkstatt-Upgrades und eine zweite Währung (Muttern)
- **Zufallsereignis**: einen Vogel antippen und einen Bonus bekommen
- **Prozedurale Musik und Sounds** – komplett im Code erzeugt, ohne Audiodateien (kleiner Synthesizer mit Akkordfolge)
- **4 Sprachen**: Russisch, Englisch, Deutsch, Spanisch
- Einstellungen für Sprache, Musik, Sound und Vibration; automatisches Speichern

## Technik

| | |
|---|---|
| Engine | Godot 4.7 (Forward+), Jolt Physics |
| Sprache | GDScript |
| Umfang | ca. 5.600 Zeilen Code in 10 Skripten |
| Grafik | 3D-Modelle werden im Code aus einfachen Formen erzeugt |

**Projektstruktur**

| Datei | Inhalt |
|---|---|
| `main.gd` | Hauptlogik: Fahren, Verkehr, Wetter, Tag/Nacht, UI, Speichern |
| `race.gd` | Boss-Rennen |
| `cars.gd` | Autos und ihre Werte |
| `showroom.gd` | Showroom / Garage-Ansicht |
| `biomes.gd` | Landschaften und Umgebung |
| `sound.gd` | Prozedurale Musik und Soundeffekte |
| `texts.gd` | Übersetzungen |
| `icons.gd` | Icons für die Oberfläche |

## Starten

1. [Godot 4.7](https://godotengine.org/) herunterladen
2. Dieses Repository klonen oder als ZIP herunterladen
3. In Godot `project.godot` öffnen und mit **F5** starten

## Geplant

Bestenliste nach gefahrenen Kilometern, mehr Verkehrsarten, weitere Bosse und Autos, Feinschliff der Balance.

## Credits

Schriftart: [Nunito](https://fonts.google.com/specimen/Nunito) – SIL Open Font License.

---

## English

**gonka** is a 3D idle driving game for smartphones (portrait mode), built with Godot 4 and GDScript. Your car drives automatically; kilometres driven are the currency. Spend them on upgrades, new cars, tuning and paint jobs. Overtake slow traffic in a timing mini-game, race bosses of four rarity tiers, collect chests to build exclusive cars, and enjoy a day/night cycle, weather and fully procedural music and sound effects generated in code. Available in Russian, English, German and Spanish.

To run: install Godot 4.7, open `project.godot`, press **F5**.

*Author: Markiian Kysil*
