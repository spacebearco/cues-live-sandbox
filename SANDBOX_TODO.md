# Sandbox to-do

Josh's open notes (2026-11-13), grouped into batches. Work one batch per session: make all the
changes, then build Mac and iOS and run the full tests once, deliver one numbered build, and log
it in `SANDBOX_CHANGES.md`. Remove items from this file as they ship. The last build was 23 (batches 1
to 3 done).

## Open

- Waveform "sticks" when scrolling in the editor. Josh said to revisit later; get a screen
  recording first.
- Lag: build 23 stops the cue blink from re-rendering the setlist screen. If it still lags,
  one re-render of that screen costs about 0.3 s on Josh's setlist and the cause is not found.

## Dropped

- "Custom clicks … have the click follow the" (Josh: ignore).
