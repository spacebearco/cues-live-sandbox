# Sandbox to-do

Josh's open notes (2026-11-13), grouped into batches. Work one batch per session: make all the
changes, then build Mac and iOS and run the full tests once, deliver one numbered build, and log
it in `SANDBOX_CHANGES.md`. Remove items from this file as they ship. The last build was 17 (batch 1,
done).

## Batch 2 – Setlist layout

Note for Blake: this reworks layout from his "Move to browser file UI" commit.

- Put the song library next to the setlist. Folder list, song list and setlist sit side by side
  and fold out like nesting dolls; no left + right split.
- Sections fold open under their song in the setlist, not in a right-click menu.
- Fix the spacing of the title at the top (ask Josh for a screenshot).
- Track headers above the waveform in the setlist view.
- If opening the editor hides the song library, it should hide the setlist too.
- Switching songs in the setlist needs a double-click, at least while the transport is rolling.

## Batch 3 – Features and glitches

- **Panic button:** one click gets the band back into the section. It gives a one-bar pre-roll:
  playback jumps to one bar before the start of the section, so everyone comes in on the
  downbeat. (Assumed: the section playing when it is pressed. Confirm with Josh.)
- **"Me time" button (Edit mode):** routes all audio to a secondary, dedicated output, on the same
  audio device or a different one. Same device is a routing change; a different device needs a
  second output and may be one for Blake.
- **Filter sweep is MIDI-mappable:** the Fade button's low-pass sweep as a mappable control.
- **Setlist faders are per song:** they follow the levels set in the editor for each song, so each
  song carries its own mix. (Today group faders are global.)
- Setlist faders are visually glitchy while dragging.
- Meters in the setlist view stutter.
- Waveform "sticks" when scrolling in the editor. Josh said to revisit later; get a screen
  recording first.

## Dropped

- "Custom clicks … have the click follow the" (Josh: ignore).
