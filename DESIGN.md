# Blitztext — Design System

Visuelle Sprache der bestehenden Menüleisten-App. Neue UI muss sich hier einfügen.

## Tonalität

- Ruhig, dicht, funktional. Deutschsprachige UI-Texte (du-Form, knapp).
- Menüleisten-Popover, feste Breite **340pt**.

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

- `SubtleButtonStyle` (Opacity-Press) für fast alle Buttons.
- `SectionLabel(text:)` für Abschnittsüberschriften.
- Chips: Capsule + 0.5pt Border, kleines `xmark` zum Entfernen (`FlowLayout`).
- Picker: `.segmented` für 2–3 Optionen, sonst Menu-Picker, `.controlSize(.small)`.
- Toggles: `.switch`, `.controlSize(.small)`.

## Neue Muster (dieser Ausbau)

- **Modus-Karte** in den Einstellungen: Name-TextField + „Aktiv"-Toggle + Modell-Picker +
  „Verarbeitung: Online/Lokal"-Picker + System-Prompt-`TextEditor` + „Auf Standard zurücksetzen".
  Übernimmt Sektionslabel-Stil, 6pt-Felder, `SubtleButtonStyle`.
- **Verfügbarkeits-Badges**: vorhandene Icons `checkmark.circle.fill` (grün) /
  `arrow.down.circle.fill` (blau) / `exclamationmark.triangle.fill` (orange) wiederverwenden.
- **Offline/Apple-Intelligence-Hinweis**: orange Info-Banner-Muster wie `accessibilityHintBanner`.

## Regeln

- Keine neuen Akzentfarben ohne Grund; bestehende Modus-Akzente nutzen.
- Sensible Hinweise (Datenfluss zu OpenAI, Aufnahmen) immer als 10.5pt `.secondary`-Caption.
- Icons aus SF Symbols, gewichtet `.medium`/`.semibold`.
