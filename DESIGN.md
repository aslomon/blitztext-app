# Blitztext — Design System

Visuelle Sprache der bestehenden Menüleisten-App. Neue UI muss sich hier einfügen.

## Tonalität

- Ruhig, dicht, funktional. Deutschsprachige UI-Texte (du-Form, knapp).
- Menüleisten-Popover, feste Breite **410pt** (vorher 340) — mehr Luft für die 5 Settings-Tabs + dichten Inhalt.
- Settings-Tabs (segmented): **Prompts · Modelle · Vokabular · Archiv · System**. Alles Wort- und Memory-bezogene lebt im **Vokabular**-Tab: Begriffe, ein zentraler Memory-Master, E-Mail Memory, Korrekturlernen und Ersetzungen. **Archiv** = nur Verlauf/Statistik/Kontext.
- Schwebende **Pille**: Kapsel-Glass (`PillGlassModifier`) für Aufnahme/Status; für erweiterte **Copy- und Varianten-Karten** ein eigener `CardGlassModifier` (abgerundetes Rechteck, 14pt-Radius, tieferer Schatten) statt Kapsel — sonst „eckiger Inhalt im Pillen-Loch".

## Farben

- Akzent pro Modus: `transcription`=blue, `localTranscription`=green, `textImprover`=purple,
  `dampfAblassen`=orange, `emojiText`=cyan.
- Status: grün = bereit/erfolg, orange = Achtung/fehlende Rechte, rot = Fehler.
- Flächen: `Color.primary.opacity(0.03–0.06)` für Karten; `controlBackgroundColor` für Felder.

## Typografie (SF, system)

- Sektionslabel: 11pt, `.medium`, `.secondary`, UPPERCASE (`SectionLabel`).
- Titel/Row-Titel: 11.5–14pt, `.semibold`.
- Fließtext/Hinweise: 10.5–11.5pt, `.secondary`.
- Monospace nur für Tastenkürzel/Pfade/Key-Maskierung.

## Abstände & Form

- Ecken-Radien: Felder 6pt, Karten/Banner 8–10pt, Capsules für Chips.
- Card-Padding 10pt, Screen-Padding 16pt.
- Rahmen: `strokeBorder(Color.primary.opacity(0.05–0.12), lineWidth: 0.5)`.

## Komponenten

- Stock SwiftUI zuerst: `GroupBox`, `Form`-artige vertikale Gruppen, native `Picker`,
  `Toggle`, `TextField`, `TextEditor`, `.bordered` / `.borderedProminent` Buttons.
- `SubtleButtonStyle` nur noch für sehr kleine Inline-/Chip-Aktionen, nicht für echte Buttons.
- Neue sichtbare Action-Buttons: `PopoverActionButtonStyle(.primary/.secondary/.warning/.danger/.quiet)`.
  Echte Aktionen dürfen nicht wie nackter Text aussehen; auch kleine Aktionen bekommen Fill/Stroke
  oder werden als Icon-Button (`PopoverIconButtonStyle`) gerendert.
- Status statt Erklärung: `BlitzStatusPill` für bereit/warnung/download/online/lokal/muted.
- Längere Hinweise nur hinter `InfoDisclosure`; Settings zeigen Zustand + nächste Aktion, keine
  dauerhafte Dokumentation.
- `SectionLabel(text:)` für Abschnittsüberschriften.
- Chips: Capsule + 0.5pt Border, kleines `xmark` zum Entfernen (`FlowLayout`).
- Picker: `.segmented` für 2–3 KURZE Optionen, sonst Menu-Picker (auch wenn die Labels lang sind), `.controlSize(.small)`.
- Toggles: `.switch`, `.controlSize(.small)`.

## Neue Muster (dieser Ausbau)

- **Dynamische Modus-Karte** in den Einstellungen: Name-TextField + „Aktiv"-Toggle +
  Hotkey-Recorder + Modell-Picker + „Verarbeitung: Online/Lokal"-Picker +
  System-Prompt-`TextEditor` + Reset/Löschen/Reihenfolge. Eigene Modi dürfen gelöscht und
  verschoben werden; feste Standard-Slots nur zurückgesetzt.
- **Hotkey-Recorder**: Ein einzelnes Aufnahmefeld startet eine explizite Aufnahme. Alle erkannten
  Tasten werden live als Keycaps angezeigt; gespeichert wird erst über `Übernehmen`, `Esc` bricht
  ab. Während der Aufnahme sind Blitztext-Hotkeys global pausiert, damit vorhandene Belegungen
  nicht auslösen. Unterstützt Modifier-only, einzelne Taste, Modifier + Taste und mehrere Tasten.
  Konflikte erscheinen direkt unter dem betroffenen Modus und blockieren `Übernehmen`.
  Tastenkürzel bleiben monospaced, aber nicht dominant.
- **Memory**: Im Vokabular-Tab ein zentraler Master-Schalter mit Status-Pill. Dieser aktiviert
  Archiv, Vokabular-Memory und E-Mail Memory inklusive Modellvorbereitung; Korrekturlernen bleibt
  ein kleiner Unter-Schalter. Vokabular-Memory lernt konservativ automatisch: Namen/Fremdwörter nach
  zwei getrennten Vorkommen, Fachbegriffe nach drei; normale Alltagswörter werden über 200+
  deutsche, 200+ englische und app-spezifische Noise-Wörter gefiltert. In Modi gibt es nur einen
  per-mode Toggle `Memory nutzen`; E-Mail zeigt zusätzlich den 3er-Segmented Picker
  (`Wenig/Mittel/Viel`). Keine langen Memory-Erklärungen in der Moduskarte.
- **Eigene Identität**: Onboarding fragt einmal nach dem eigenen Namen. Derselbe Wert steht im
  Vokabular-Tab und wird lokal als feste Schreibperspektive (`Ich schreibe als ...`) sowie als
  Spracherkennungs-Hinweis verwendet. Das ist kein E-Mail-Memory, sondern Basis-Kontext für alle
  Rewrite-Modi; E-Mail-Kontext kann damit Absender/Empfänger sauberer aus `Von`/`An` ableiten.
- **Varianten-Karte in der Pille**: zwei gleich gewichtete Textkarten, je `Einfügen` und
  `Kopieren`. Keine automatische Paste, solange die Karte sichtbar ist.
- **Verfügbarkeits-Badges**: vorhandene Icons `checkmark.circle.fill` (grün) /
  `arrow.down.circle.fill` (blau) / `exclamationmark.triangle.fill` (orange) wiederverwenden.
- **Offline-/Lokal-Hinweis**: orange Info-Banner-Muster wie `accessibilityHintBanner`.

## Regeln

- Keine neuen Akzentfarben ohne Grund; bestehende Modus-Akzente nutzen.
- Sensible Hinweise (Datenfluss zu OpenAI, Aufnahmen) immer als 10.5pt `.secondary`-Caption.
- Icons aus SF Symbols, gewichtet `.medium`/`.semibold`.
- User-Journey pro Bereich: oben Status, dann primäre Aktion, dann optionale Details.
- Onboarding ist Setup, nicht Handbuch: pro Schritt maximal eine Hauptentscheidung oder ein
  Berechtigungs-/Installationsstatus.
- Liquid Glass nicht stapeln: Popover/Floating-Pill bekommen Glass; innere Settings-Flächen nutzen
  native SwiftUI-Controls, damit macOS 26 den Systemlook selbst rendern kann.

## App- und Menüleisten-Icons

- App-Icon: alte schwarze Originalfläche mit linksbündigem Blitztext-Balkenmark. Das Mark darf
  größer skaliert werden, um unnötigen transparenten/ungenutzten Rand zu reduzieren. Keine diagonal
  versetzten Balken, keine neuen Zusatzsymbole, keine lauten Illustrationen.
- macOS 26 Icon: `AppIcon.icon` ist die primäre Liquid-Glass-Quelle. Der schwarze Hintergrund liegt
  als Icon-Composer-Fill an, die weißen Balken als separates SVG-Layer; `AppIcon.icns` bleibt nur
  Fallback für ältere macOS-Darstellungen.
- Menüleisten-Icon: Idle bleibt das einfache Template-Icon. Während Aufnahme/Verarbeitung keine
  mode-spezifischen Badge-Symbole; nur das normale Zeichen plus kleiner pulsierender Statuspunkt.
