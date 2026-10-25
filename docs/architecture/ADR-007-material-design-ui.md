# ADR-007: Material 3 user interface

- **Status:** Accepted — supersedes the PRD's monochrome "Nothing-style" UI contract
- **Date:** 2026-10-25
- **Decided by:** project owner

## Context

The first UI followed the PRD: pure black and white, monospace text, square corners and bracketed `[ BUTTONS ]`. In use it read as harsh and hard to scan. It also used emoji-like glyphs (⚠ ■ ✕ ●) and text block bars (█░) for scores. The owner asked for a Google Material-inspired design that feels authentic, is minimal and precise, uses custom SVG icons instead of emoji, and doesn't confuse people.

## Decision

- **Material 3:** seeded from Google blue `#1A73E8`, with tonal surfaces, rounded cards and pill buttons. Light and dark themes follow the system setting.
- **Red means emergency, and only that.** It's reserved for the SOS action, critical urgency and dangers, so it never decorates.
- **Custom SVG icons** (`lib/ui/icons.dart`): 47 original icons on a 24 px grid with a 2 px rounded stroke, rendered with `flutter_svg` and tinted from the theme. No emoji, no icon font.
- **Never colour alone.** Status always pairs colour with an icon and text (`StatusChip`, `Callout`, `InfoRow`).
- **Plain language, not system codes:**
  - victim requests show a six-step timeline (Saved → Sent → Received → Accepted → On the way → On scene);
  - responder offers explain "Why you were matched" with real progress bars;
  - copy is in sentence case.
- **Honesty rules unchanged:** a local save is never shown as delivery, acceptance never claims arrival, and simulation is always labelled.

## Consequences

- Visual meaning moved from "monochrome + text" to "tonal colour + icon + text". This stays accessible because no state depends on colour alone.
- Roboto Mono remains only for fingerprints and coordinates, which people compare character by character.
- Widget tests render every screen at 360×800 dp, so layout overflows fail the build.
