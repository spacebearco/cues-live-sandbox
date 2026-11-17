# Sandbox to-do

Josh's open notes, updated 2026-11-17. Work one batch per session: make all the changes, then
build Mac and iOS and run the full tests once, deliver one numbered build, and log it in
`SANDBOX_CHANGES.md`. Remove items from this file as they ship. The last build was 24
(batches 1 to 3 of 2026-11-13 done).

Blake's code takes priority. Where his main covers or conflicts with an item here, his version
stays and the item is fitted to it or dropped.

## Step 0 – Build the rebase onto Blake's main at `c6bb673`

The rebase is done and verified (see `SANDBOX_CHANGES.md`): Mac and iOS build clean and the
full tests pass. Deliver it as build 25 for Josh to retest the two open items below. Then start
batch 4.

## Batch 4 – Small add-ons (after the rebase)

All UI or editing work, none in the audio engine. Check each against Blake's main first.

- **Undo mute and solo.** M and S change the track before the undo snapshot is taken, so undo
  restores nothing (build 13). Take the snapshot first.
- **Setlist fader moves on the undo stack.** A setlist fader writes the song's track gains
  (build 21) but can't be undone in the editor.
- **Split to Mono lanes draw one channel.** A split track's lane still draws both channels of
  the file (build 12).
- **Folding the folder column narrows the pane** instead of widening the song list (build 18).
- **Drag to scrub in Edit mode.** The setlist playhead is click to place only (build 14). Blake's
  setlist gestures leave drag to the scroll view for panning, so this needs a modifier or a
  drag on the ruler only.
- **Remote PIN lockout.** No rate limit or lockout on wrong PINs.
- **Mixer `isPlaying` order.** It can briefly update out of order. Find the cause first.

## Open (needs Josh)

- Waveform "sticks" when scrolling in the editor. Blake's PR #4 (scroll re-renders: bookmark
  resolution and clip hover were rebuilding the editor) likely fixes this. Josh to retest after
  the rebase; if it still sticks, get a screen recording.
- Lag: one re-render of the setlist screen costs about 0.3 s on Josh's setlist, cause not found.
  Blake's setlist waveform rework may change this. Josh to retest after the rebase; if it still
  lags, it needs an Instruments run.

## Not in scope here (major or engine work, for Blake)

- Transpose crackles (Signalsmith Stretch CPU on the render thread).
- Short dropout when Me Time switches devices.
- Library database deleted silently on a failed open or a `storeVersion` bump.
- `AudioEngineManager.swift` and `PlaybackCoordinator.swift` over the 800-line limit.
- Cloud sync, MCP server and show redundancy (Blake's plans in `docs/`).

## Dropped

- "Custom clicks … have the click follow the" (Josh: ignore). Blake has since rebuilt click
  generation.
