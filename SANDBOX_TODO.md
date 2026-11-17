# Sandbox to-do

Josh's open notes, updated 2026-11-17. Work one batch per session: make all the changes, then
build Mac and iOS and run the full tests once, deliver one numbered build, and log it in
`SANDBOX_CHANGES.md`. Remove items from this file as they ship. The last build was 25
(the rebase onto Blake's `c6bb673` and batch 4).

## How to work here

- **Where:** the Mac mini, in this folder, on the `sandbox` branch. It has Xcode, so every change
  is built and tested before a build ships. Josh drives sessions from the MacBook or phone with
  Remote Control. Cloud sessions can't compile; use them only for planning or writing, and pull
  their work here before building.
- **Blake's main:** merge it in, don't rebase onto it:
  `git fetch upstream && git merge upstream/main`. `sandbox` is pushed and its build hashes are
  in the build notes, so it is never rewritten or force-pushed.
- **Parallel work:** only when two sessions really run at once. Each gets a worktree branch, which
  is merged into `sandbox` and deleted when done. No backup or side branches left behind.
- **One batch, one build:** make the batch's changes and commit them, then run
  `Scripts/make-sandbox-build.sh <number> "<label>" "<change>" ...`. It checks Mac, iOS and the
  tests, builds with the fork's signing, copies the app to Dropbox and adds the build notes
  entry. Then log the build in `SANDBOX_CHANGES.md` and `git push origin sandbox`.
- **Feedback:** Josh tests on the MacBook from Dropbox; his notes go into this file as the next
  batch.

Blake's code takes priority. Where his main covers or conflicts with an item here, his version
stays and the item is fitted to it or dropped.

## Open (needs Josh)

- Retest in build 25: undo of M / S / knobs, undo of a setlist fader in the editor, Split to Mono
  lanes, folding the folder column, and drag to scrub in Edit mode.
- Mixer `isPlaying` can briefly update out of order: no cause found in the code. Needs steps to
  reproduce (which screen, what was clicked) or a screen recording.
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
