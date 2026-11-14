# Sandbox changes

A running log of what changed in this fork (`spacebearco/cues-live-sandbox`, branch
`spacebear/fixes`) compared with `blakeccross/cues-live`. Since build 15 the branch is based on
Blake's main at `f18a137`. The fork is a sandbox for features
Josh wants in cues.live: everything here is a working demo of an idea. Blake decides what goes
into the real app and how.

Each entry gives the request in Josh's words where useful, what changed, how it works, the main
files, the tests, and anything Blake should know before taking it. Builds are the numbered apps
in the Dropbox `Sandbox/Cues App` folder (`cues.live NN – Label.app`).

Newest first.

---

## Build 17 – Batch 1 quick fixes

From Josh's notes of 2026-11-13 (`SANDBOX_TODO.md`, batch 1). One build for the whole batch.

- **Next Beat quantize removed.** `ShowQuantize` is End of Section or Next Bar. A saved "beat"
  setting no longer decodes, so `@AppStorage` falls back to End of Section. The beat planning
  code and its tests are gone (`ShowJumpPlanner.swift`).
- **Show mode hides what isn't for the gig:** the Jump menu and the Song Editor toolbar button
  are hidden, not just disabled. Cues still fire on the saved Jump setting.
- **Show | Edit switch at the far top right:** it is now the last item in the setlist toolbar
  (`LiveSetlistToolbar.swift`).
- **Hotkey for the editor:** Command-E opens (or closes) the song editor from the setlist, in
  Edit mode only. It is a shortcut on Blake's toolbar toggle, and listed in Help ▸ Shortcuts.
- **CLIP light resets the setlist meter** when clicked.
- **Group faders reset to unity** on a double-click or a Command-click (`MixerFaderColumn`).
- **Faders reach +10 dB** (was +6). `MixerFaderScale` marks are now every 10 dB: +10, 0, −10 …
  −60. The editor's gain knob and typed values share the scale, so they also reach +10.
- **Stereo meters:** the setlist group meters and the editor's track meters show left and right.
  `PeakMeterHolder.reportStereo` keeps a falling peak and a smoothed RMS per side
  (`StereoMeterLevels`); `AudioEngineManager.trackStereoLevels(id:)` and
  `groupStereoLevels(for:)` read them. The mono `trackRMSLevel` / `rmsLevel` were removed.
  Group meters show peak per side; track meters show RMS with peak above, per side.
- **Click a section marker to play it:**
  - Setlist: a click on a section's name label plays that section. Stopped, it starts from the
    section's first beat. Playing, Show mode cues it and Edit mode jumps at once
    (`LivePlaybackView.playSection`). The click target sits above Blake's waveform tap gesture.
  - Editor: a click on a marker in the section ruler runs the existing cue action (play from the
    section when stopped, cue it when playing). In the editor window that follows the setlist,
    Blake's rule still applies and the click does nothing there.
- **Tests:** `ShowJumpPlannerTests` (beat fallback), `MixerFaderScaleTests` and
  `TrackMixControlsTests` (+10), `SplitToMonoTests.testStereoLevelsFollowEachSideAndClearOnReset`.
  Build 16 got its missing full run first: 425 passed.

---

## Build 16 – Meter fix, section-first quantize, fade in bars, audible sweep, mode badge

- **Setlist meter froze:** the sampling loop now belongs to each meter view's own `.task`, so a
  view that Blake's layout rebuilds can't stop another view's loop. `MixMeterBus` also waits only
  for measured tracks, skips a measured track that has stopped rendering, and lets a stalled track
  rejoin at the read position. Tests in `MixMeterBusTests`. Not confirmed on Josh's machine.
- **Quantize reworked:** a cue always targets the clicked section. The Jump menu (End of Section /
  Next Bar / Next Beat) picks when it fires. This applies to clicks, the section list, mapped keys
  and remote cues (`cueSection` → `ShowJumpPlanner.fireTime`). The menu shows in both modes.
- **Fade length in bars** (1, 2, 4, 8 or 16; default 4), worked out from the song's tempo and meter
  at the bar playing (`FadeButtonSettings.duration`, `PlaybackCoordinator.fadeButtonDuration`).
- **Sweep audibility:** the filter now moves ahead of the level (`sweepCurve`), and the editor's
  Fade button carries the sweep too. A real-engine test confirms a closed sweep cuts 5 kHz by more
  than 40 dB (`FadeFilterEngineTests`).
- **Meter stutter during fades:** `GroupMixFadeController` keeps in-between levels itself and
  lays them over the engine's group mix (`applying(to:)`). It writes the groups' volumes once,
  when the fade lands, instead of 60 database writes and fetches a second.
- **Show / Edit badge:** a red SHOW (lock) or blue EDIT (pencil) badge beside the mode switch.

---

## Build 15 – Rebased onto Blake's main, Show mode locks

### Rebased onto Blake's main
- **What:** `spacebear/fixes` now sits on `blakeccross/cues-live` main at `f18a137` ("Move to
  browser file UI"), ten commits newer than the sandbox's old base (`e93608c`). Blake's code took
  priority: where both sides changed the same thing, his version was kept and the sandbox feature
  was fitted to it or dropped.
- **History:** the 18 sandbox commits were replayed onto his main as one change, since
  his rewrites touched the same files over and over. The original commit-by-commit history is
  kept, unpushed, on `spacebear/fixes-before-rebase`. The build sections below still describe
  each feature as first built; this section says what changed in the rebase.
- **storeVersion:** unchanged at 21. Blake added a `SongFolder` model, which SwiftData adds in place.
- **Fork setup kept:** bundle ID `com.spacebear.cues` (tests `com.spacebear.cues.tests`), no
  team, ad-hoc signing and Hardened Runtime off on the CuesLive target, Sparkle off without a feed.
  Re-applied to his project file; nothing else in it was changed apart from registering new files.

**Dropped (Blake's version covers it):**
- **Build 08 – editor handoff.** The pushed editor taking over the playing setlist song
  (`PlaybackCoordinator+EditorHandoff`, `adoptingPlayback`, the setlist-side handoff) is gone.
  On the Mac, Blake's editor is now its own window that follows the setlist and applies edits live
  (`SetlistEditorLink`, `PlaybackCoordinator+LiveEdits`). The pushed editor (iOS) pauses the
  setlist again, as in his code.
- **Build 08 – stacked mapping sessions and editor key mapping.** Blake built the same
  session stack in `InputMappingController` (with a per-session playback switch), plus his own
  editor mapping (`handleMappedLiveAction`, off while the editor follows the setlist). Ours, its
  test, and `EditView+Mapping.swift` were removed.
- **Build 04 – editor No Output silencing (and build 02's editor timecode guard).** Blake's
  editor always plays through the show routing ("Output groups respected in edit view"), so
  `MasterMixSilencedGroups` and the guard were removed.
- **Build 01 – ⌘-scroll zoom in the editor and setlist.** Replaced by Blake's scroll-wheel
  zoom. Our ⌘-scroll is kept only in the setlist overlap editor, which his doesn't cover.
- **Build 03 – library multi-select delete.** Blake's new library has its own multi-select
  delete with confirmation. `SongLibraryPanel+Removal.swift` was removed.
- **Song library inside the editor:** Blake removed the editor's library sidebar, which also
  removed our "hide quick edit for the song open in the editor" rule.
- **Build 01 – editor body split and tempo prompt helpers:** superseded by Blake's editor
  structure and `EditSheet`.

**Reworked to fit Blake's code:**
- **Batch folder import (build 03):** now in Blake's `SongLibraryPanel+Import`. The open panel
  allows several folders, and a folder of song folders expands (`SongFolderImporter.songFolders`).
- **Quick edit of key, tempo and meter (build 06):** "Key, Tempo & Meter…" in Blake's library
  right-click menu opens it as a sheet. The row button and the row's key/tempo/meter line went
  with the old library.
- **Library sort order is remembered (build 01):** moved onto Blake's `SongLibraryPanel`.
- **Insert Bars (build 02):** now a case in Blake's `EditSheet`.
- **Fade time and filter sweep (build 12):** the right-click menu is a shared `FadeSettingsMenu`,
  attached to Blake's toolbar Fade toggle in the setlist and to the editor's Fade button.
- **Setlist meter (build 07):** to the right of Blake's new setlist layout. The transport is
  now in his toolbar.
- **Show / Edit mode (build 14):** the switch is in Blake's setlist toolbar. His waveform view
  now reports every click's time to the setlist instead of mapping clicks to sections itself.
  Show mode on Section repeats his rule: inside a section cues it, outside seeks.
- **Section colors (build 12):** passed into Blake's new setlist painter (`LiveSetlistLaneCanvas`)
  and section labels.
- **Click a song with no sections (build 01):** re-applied in Blake's `NonCurrentSongSelectTapModifier`.
- **M/S hiccup fix (build 13):** `SongUndoFocusedValue` is also used by Blake's editor window
  (`SetlistSongEditorHost`), since that's the Mac editor now.
- **Edit head (build 11):** drawn alongside Blake's "playhead only for the song the engine is
  playing" rule.
- **Song Key / Transpose (build 04):** on Blake's Change Key menu items, renamed Transpose.
- **Timeline tail (build 10):** on Blake's zoom code.
- Everything else (engine work, snapping, mute, clipboard, knobs and meters, waveform size,
  section list, arrows, detect status, split to mono, Timecode default) applied without changes.

### Show mode locks
- **Request:** Show mode "should lock" solo, routing changes and editing.
- **Change:** in Show mode the song editor can't be opened (toolbar toggle disabled, Edit Song
  ignored), switching to Show closes an open editor, and the output routing settings are disabled
  with a "Locked in Show mode" note. Solo lives only in the editor's track headers, so locking the
  editor locks solo.
- **Default is now Edit**, so a fresh install isn't locked out of setup. A saved choice is kept.
- **Files:** `ShowJumpPlanner.swift` (`SetlistPlayMode.defaultMode`, `lockedExplanation`),
  `LivePlaybackView.swift`, `LiveSetlistTransportToolbar.swift`,
  `OutputRoutingSettingsForm.swift`, `SetlistModeControls.swift`.

---

## Build 14 – Setlist Show / Edit mode with quantized jumps, key fixes, per-song waveform size

### Setlist Show / Edit mode
- **Request:** "a dedicated playhead in the setlist view so I can listen to any part of the song and
  not be locked in the sections. Make a Show and Edit mode. In show mode, lock it to only quantize
  jumping, but in edit mode, let me have a free playhead that tracks the edit view playhead."
  Plus: "Make 3 show quantize modes: a bar, a beat, and a section out."
- **Change:** a **Show | Edit** switch in the setlist toolbar, remembered between launches.
  - **Show:** a click on the playing song cues a jump, set by the **Jump** menu beside the switch:
    - **Bar:** to the start of the clicked bar, when the current bar ends.
    - **Beat:** to the clicked beat, on the next beat (quarter notes).
    - **Section:** to the clicked section, when the current section ends. This is the old
      behavior; a click outside any section still seeks.
    Stopped, a click moves straight to the bar or beat line (or section start). Clicking a
    cued section again cancels it, as before.
  - **Edit:** a click moves the playhead to exactly that spot, playing or stopped, and cancels any
    cue or loop. The setlist and the editor share one engine, so the setlist playhead is the
    editor's playhead when you open and close the editor (build 08).
- **How:** `ShowJumpPlanner` (pure; bar/beat target and fire time from the song's tempo map) with
  `SetlistPlayMode` / `ShowQuantize`. `LivePlaybackView+PlayMode.swift` routes clicks. Bar and
  beat jumps use the existing scheduled-transition path (`scheduleSectionTransition` →
  sample-accurate jump in the engine). A new `cueTargetTime` lets `fireMarkerCue` land on a grid
  time instead of a section start. A jump outside every section uses a placeholder cue ID so the
  cue monitor still fires. The waveform's tap gesture now only reports the clicked time; its
  section-hit logic moved into the setlist.
- **Not done:** the Show mode lockouts Josh described earlier (solo, routing changes, editing).
  Show mode currently only governs clicks on the waveform. There is no drag-to-scrub; Edit mode
  is click to place.
- **Tests:** `ShowJumpPlannerTests`.

### Typed gain / pan values now apply on Return
- **Report:** "when I type in a value for the volume and hit enter, it does not input the value."
- **Cause:** build 11's editor Return shortcut (edit head to playhead) took the Return key even
  while a value box was being typed in.
- **Fix:** the editor's Return and arrow shortcuts stand aside while any text field has the
  keyboard (`KeyboardInputMonitor.isTextInputFocused`, now internal).

### ← / → between sections now work
- **Cause:** macOS flags arrow-key presses as keypad keys, so the "no modifiers" check from build 13
  rejected every arrow press. The check now ignores that flag.

### Waveform size per song
- **Request:** "can the waveform be per song?"
- **Change:** ⋯ ▸ Waveform Size now sets the size for the open song only, remembered between
  launches (`WaveformSizeStore`, a UserDefaults dictionary keyed by song ID; songs never set
  draw at 1×). The earlier global setting is no longer used.

### Test note
- In the full run, `OutputRoutingManagerTests.testBuiltInDevicePlaysOutputTwoOnlyOnTheSecondChannel`
  and `SectionCueEngineTests.testCuedSectionsKeepClickTrainIntactForGeneratedClick` failed once
  each and passed when re-run alone. Both drive real audio hardware. The second is on AGENTS.md's
  list of timing-sensitive tests.

---

## Build 13 – Cleaner track headers, M/S hiccup, section arrows, detect status (f50f15a)

### Track header layout
- **Request:** "clean up the visual of the tracks. The spacing isn't even. Also if I make the track
  bigger, the group moves down with it."
- **Change:** name, mix row and group menu stack from the top at a fixed 6 pt spacing and 22 pt
  rows, so a taller lane only adds empty space below. M, S, gain and pan are one even row: gain
  and pan are 22 pt chips the height of M and S, with a fixed-width value centered beside each knob.
- **Cause of the moving group:** the group menu used `.buttonSizing(.flexible)`, which on macOS 26
  also stretches it vertically, centering the label in the lane. It now has a fixed height.
- **Files:** `TrackLaneHeaderView.swift`, `TrackKnobField.swift`.

### Mute / solo click hiccup (editor track headers)
- **Report:** clicking M or S in the editor hiccups.
- **Changes (confirmed by Josh on build 13: M and S are smooth now):**
  1. The Edit menu's undo state (`canUndo`, action names) was read in `SongDetailView.body`, so
     every undoable click (each M/S is one) re-rendered the whole editor. It now lives in
     `SongUndoFocusedValue`, a modifier whose body is the only thing that refreshes.
  2. Each mix change saved the SwiftData context immediately, which makes every `@Query` in the
     window fetch again, including the song library sidebar. `SongEditorViewModel` now coalesces
     those saves to 1.5 s after the last change. The audio still changes at once, and the editor
     writes the project file on close as before.
- **Known, not fixed:** M/S toggle the model before the undo snapshot is taken, so undoing a
  mute or solo restores nothing. This was already the case before the sandbox.

### ← / → jump between sections
- **Request:** "When in the edit view, I want to be able to arrow key left and right between sections."
- **Change:** with the timeline focused, → goes to the next section's start and ← to the start of
  the current section (or the previous one if already within half a second of the start).
  Stopped, the edit head moves there. Playing, playback jumps there too. Arrows with modifiers
  keep their old meanings.
- **Files:** `EditView+SectionNavigation.swift`, `SongTimeline.swift`
  (`previousSectionStart` / `nextSectionStart`). **Tests:** `SectionNavigationTests`.

### Status while detecting sections
- **Request:** "status text that appears whenever it is detecting sections."
- **Change:** a "Detecting sections…" bubble with a spinner floats over the top of the timeline
  for as long as detection runs. Before, only the menu item's label changed.

### Waveform size moved into the ⋯ menu
- **Request:** "The waveform bar … is in an odd place. Can that be a floating bar within the
  settings menu?"
- **Change:** the toolbar slider is gone. ⋯ ▸ **Waveform Size…** opens a small floating panel
  with the slider, the current value and Reset. The size is global for every song's editor and
  remembered between launches. It is not saved per song.

---

## Build 12 – Fade time and filter sweep, section colors, waveform size, knobs and meters, split to mono (fe74efd)

### Fade button: adjustable time and a low-pass sweep
- **Requests:** "I want to be able to change the fadeout time of the fade button at the bottom."
  "Can you add a filter sweep to the volume fade in and out to make it more musical? It would be a
  low pass filter that changes with the volume fade."
- **Change:** right-click the Fade button to pick 1–30 seconds (default 5) and to turn
  **Filter Sweep** on or off (on by default). The tooltip shows the current setting. With the
  sweep on, a low-pass filter closes from 20 kHz to 150 Hz (exponentially) as the fade goes out
  and opens again as it comes back. It affects the same groups the fade does: everything except
  Click and Timecode.
- **How:** `FadeButtonSettings` (UserDefaults keys shared with `@AppStorage` in the menu).
  `GroupMixFadeController` ramps `filterClosure` alongside the volumes. The closure rides in
  `GroupMixSnapshot.fadeFilter` through the coordinator's group-mix provider, so it reaches the
  engine on every fade step and after song loads. `applyAllMixSettings` sets it per track, and
  each `TrackMemoryPlayer` runs a `LowPassSweep` (RBJ biquad, coefficients per block, bypassed
  and reset at 0, limited to 5% movement per block) after gain and pan.
- **Scope:** setlist Fade button only (the editor's fade button has no sweep).
- **Tests:** `LowPassSweepTests` (open is bit-transparent, closed cuts 5 kHz to under −43 dB and
  keeps 60 Hz, cutoff curve).

### Section names and colors in one list
- **Request:** "In the song arrangement sections, I want to be able to edit the color and name
  instead of having to set up each color and name by clicking each marker."
- **Change:** in the editor's Song Arrangement sheet, each row has a color swatch menu
  (Automatic + 9 colors) and an in-place name field (Return or clicking away saves). Each change
  is one undo step. Editor section markers now show the section's color (they were all gray), the
  same color the setlist waveform uses.
- **How:** `ArrangementMarker.colorIndex` (optional, nil = automatic by position, decodes as nil
  from older files), passed through `SongSection.colorIndex`. `ArrangementSectionPalette` gained
  Green, Red and Gray. Automatic colors still cycle through the original six, so existing songs
  look the same. `EditView+SectionList.swift`.
- **Tests:** `SectionColorTests`.

### Global waveform size
- **Request:** "a global slider to change waveform size like in Logic Pro."
- **Change:** a waveform slider in the editor toolbar scales how tall waveforms are drawn inside
  clips, 0.5×–4×. Double-click the icon to reset. It's remembered between launches and doesn't
  change track heights or the audio.
- **How:** `WaveformSizeControl` (`@AppStorage("editorWaveformScale")`) → `TimelineLaneCanvas` →
  `TimelineLanePainter.Scene.waveformScale`, applied as extra gain on the drawn columns and
  sample strokes (clipped at the clip edge, as in Logic).

### Track header: gain and pan knobs, peak + RMS meter
- **Request:** "I really want peak+rms meters for each track." Also: "the fader can go away.
  There just needs to be a [gain] knob and a value you can type in. Same for pan."
- **Change:** each editor track header has a gain knob and a pan knob, each with its value
  beside it. Drag the knob up or right, click the number to type, double-click the knob to reset.
  A thin meter on the header's right edge shows RMS (solid green) with the sample peak above it
  (lighter; yellow above −6 dB, red at full scale), on a −60…0 dB scale.
- **How:** `TrackKnobField` replaces the drag-box `TrackValueField`. `TrackVolumeField` /
  `TrackPanField` keep their behavior and typed-value parsing. `PeakMeterHolder` also keeps a
  smoothed mean square (about 300 ms) from each render block, falling away when the track stops
  reporting. `AudioEngineManager.trackRMSLevel(id:)`; `TrackLevelMeter`.

### Split stereo track to mono
- **Request:** "can we make a split to mono option?" (two mono tracks, L and R).
- **Change:** right-click a stereo track header ▸ **Split to Mono**. The track becomes "Name L"
  (left channel, panned hard left), and a new "Name R" (right channel, panned hard right) appears
  below it with the same mix, group, trims and clips. One undo step. The song reloads, so playback
  stops.
- **How:** `AudioTrack.sourceChannel` (optional; saved in `.cueslive` inside the track's mix as
  `sourceChannel`, and in undo snapshots). `SongTrackLoader` wraps the stream in
  `ChannelSelectedSource`, which serves the chosen channel to both output channels, so the engine
  and render code are unchanged and no audio is rewritten. `TrackChannelSplitter`.
- **SwiftData:** a new optional attribute, which migrates in place. Checked on the Mac mini's
  existing store: no reset logged, and the column was added. `storeVersion` was deliberately not
  bumped (a bump wipes the library; see Open issues).
- **Not done:** a split track's lane still draws both channels of the file.
- **Tests:** `SplitToMonoTests` (channel adapter, split result, saved field, RMS).

### Looked into, not changed: mute/solo hiccup
- Josh reported "solo and mutes stutter a little bit" on click. A likely audio cause (silent tracks
  not keeping their disk read-ahead in step) was tested on the real engine and made no measurable
  difference, so nothing was changed. The remaining suspect is the editor redrawing and saving the
  library on each click. Waiting on where it happens (editor or setlist mixer) and whether it's
  the sound or the screen.

---

## Build 11 – Edit head and playhead (9a667a7)

- **Request:** "Is it possible in edit mode to have a playhead and an edit head?"
- **Before:** the editor already kept a separate insertion point, and clicks didn't move playback.
  But the insertion cursor blinked only on the clicked track and hid during playback, and ⌘T
  split at the playhead while Paste used the insertion point.
- **Change:**
  - A blue **edit head** runs through the ruler and every lane, with a marker in the ruler. It is
    always visible, playing or stopped. The red playhead is unchanged and draws on top. While a
    time range is selected, the range shows instead.
  - A click moves only the edit head, even mid-song.
  - **⌘T** splits at the edit head (or both edges of a selected range). **⌥⌘T** splits at the
    playhead. Both cut the selected clips plus any clip on a selected track that the cut crosses,
    so clicking a track and pressing ⌘T works without selecting the clip first.
  - Paste, Insert Bars and Play already worked from the edit head.
  - **Return** moves the edit head to the playhead. **Shift-Return** jumps playback to the edit
    head while playing.
  - Help ▸ Shortcuts lists the new and recent editor shortcuts.
- **How:** `insertionTime` is the edit head. `EditView+EditHead.swift` holds the actions and the
  Return handling. `Views/Timeline/TimelineEditHead.swift` draws it as a viewport-pinned canvas,
  like the following playhead, so scrolling never re-lays it out. `EditStemTimelineView` takes
  `editHeadTime`. The per-lane blinking `TimelineInsertionCursor` and its color were removed.
- **Files:** also `EditView+Clips.swift`, `EditView.swift`, `CuesLiveApp.swift` (Edit menu),
  `DAWColors.swift` (`dawEditHead`), `DocsWindowView.swift`.

---

## Build 10 – Room after the song end, Timecode defaults to No Output (9049fae)

### Editor timeline extends past the end of the song
- **Request:** "When an audio file goes all the way to the end of the timeline, I cannot edit it
  because the scroll bar gets in the way."
- **Cause:** the editor drew the timeline exactly as long as the song. When the zoom fits the
  whole song, the last clip's right edge (and its trim handle) sits under the window's scroll bar.
- **Change:** the editor draws a tail of empty space after the song: 4 seconds or 4% of the song,
  whichever is longer. Fit-to-window zoom includes the tail, so the song's end always has room.
- **How:** `EditView.songEndTime` is the real end (last clip or marker). `timelineDuration` is now
  `songEndTime` + tail and drives drawing, rulers, hit-testing and zoom. Adding a section and
  detecting sections still clamp to `songEndTime`. Playback, the engine and the setlist are untouched.
- **Files:** `Views/Songs/Edit/EditView+Timeline.swift`, `EditView+Sections.swift`,
  `Views/Timeline/TimelineLayout.swift` (`minimumTailSeconds`, `tailFraction`).

### Timecode group defaults to No Output
- **Request:** "Can we make the Timecode group default out to No Output?"
- **Change:** a Timecode group with no saved route plays to No Output on every device, in
  Settings and in playback. A route the user picks still wins.
- **How:** `OutputRoutingStore.timecodeGroupID(in:)` finds the group by name
  (`TimecodePlaybackSupport.isTimecodeGroup`). `route(for:deviceUID:in:)` (Settings) and
  `snapshot(in:channelCount:)` (playback) fall back to `.none` for it.
- **Note for Blake:** a `.none` route counts as non-default routing, so with a Timecode group
  present the engine always uses the channel-map path rather than the plain master mixer, even
  on a stereo device. That path was already used whenever anyone routed a group, but it is now
  the default.
- **Tests:** `CuesLiveTests/TimecodeDefaultRouteTests.swift`.

---

## Build 09 – Clean live edits, clip mute, cut / copy / paste (1463597)

### Live edits without blips
- **Request:** after build 08, editing while the song played "blips for a second".
- **Causes:**
  1. Every edit refreshed every track's clip map, and each refresh dipped the track (build 08's
     swap fade), so the whole mix dipped.
  2. Stems stream from disk with about 6 s resident around the playhead. An edit that sends the
     playhead to another part of the file read silence until the reader caught up (40 ms timer
     plus decode).
- **Changes:**
  - `ArrangementTimelineMapper` is `Equatable`. A track whose mapping did not change is skipped.
  - `firstDifference(from:at:within:)` compares old and new mappings over the next 100 ms (5 ms
    steps: source position, clip gain, speed). If nothing changes at the playhead (a split, an
    edit elsewhere) the new map applies at once with no fade.
  - If the audio at the playhead does change, `StemSampleSource.preload(fromSourceFrame:)` reads
    about 1 s of the new region (without evicting the current window) before the fade swap.
  - Streaming sources also read ahead to the next clip's audio when it jumps elsewhere in the
    file: `mapper.upcomingJumpSource(...)` → `noteUpcomingJump(toSourceFrame:)` from the render
    thread (trylock, no allocation), and the reader keeps those pages resident. This also helps
    ordinary playback of rearranged songs, where crossing into a moved clip could drop out briefly.
  - `StreamingStemBuffer` moved out of `DecodedStemBuffer.swift` into its own file (that file was
    over the 800-line limit).
- **Files:** `Services/Editing/ArrangementTimelineMapper.swift`,
  `Services/Playback/TrackMemoryPlayer.swift`, `StreamingStemBuffer.swift`,
  `DecodedStemBuffer.swift` (protocol additions).
- **Tests:** `LiveEditPlaybackTests` (real engine: plays a tone, splits ahead of the playhead and
  then re-points the clip under the playhead far into the file; asserts no dropout from the
  split and under 20 ms from the jump; it fails if the preload is removed),
  `ClipMuteAndClipboardTests` (mapper comparison and jump look-ahead).

### Clip mute
- **Change:** `TrackClip.isMuted`. A muted clip stays on the timeline, dimmed, and plays nothing.
  Control-M, Edit ▸ Mute / Unmute Regions, or the clip menu. With a time range selected, clips
  on the selected tracks are split at the range edges so exactly the range is muted. Toggling
  again unmutes.
- **How:** the mapper drops muted clips, so playback treats them as gaps. `ClipEditing+Mute.swift`
  holds the edits. Copies, splits, tempo re-timing and song duplication keep the flag.
- **Format:** `isMuted` is written to `.cueslive` only when true and decodes as false when
  missing, so files from before the change load unchanged.

### Cut / Copy / Paste clips
- **Change:** Command-X / C / V (and the clip menu). They act on the selected range when there is
  one (clips crossing the edges are copied in part), otherwise on the selected clips. Paste lands
  at the insertion point (or range start) on the tracks the clips came from, replacing what is
  there.
- **How:** `Services/Editing/ClipClipboard.swift` (pure, tested). The editor keeps the clipboard
  in `@State`. Copying puts a marker string on the system pasteboard so the standard Edit menu
  offers Paste, and Paste only uses the editor's clips while that marker is still there. It uses
  SwiftUI `onCopyCommand` / `onCutCommand` / `onPasteCommand`, so it needs the timeline focused.
- **Files:** `EditView+ClipClipboard.swift`, `ClipLaneInteraction.swift`, `WaveformLaneView.swift`,
  `CuesLiveApp.swift` (menu item).

---

## Build 08 – Edit the playing song without stopping (07b6ef0)

- **Request:** "Combine the setlist and edit audio engines so there's no stopping. Editing
  mid-song is imperative." Also "spacebar doesn't play in the edit view".
- **Before:** opening the editor paused the setlist, unloaded every track and reloaded them for
  the editor; closing reloaded them again.
- **Change:** opening the editor on the song the setlist has loaded hands over the running engine
  as it is (position, show routing, group mix, playing or paused). Closing hands it back. If the
  editor kept the same tracks, the saved arrangement, tempo and mix are applied live and
  auto-advance and overlap scheduling are re-armed. Otherwise the song reloads as before.
- **How:**
  - `PlaybackCoordinator+EditorHandoff.swift`: `beginEditorHandoff(songID:)` returns an
    `EditorPlaybackHandoff` (song ID + the engine's track-load generation) only when that song is
    loaded, nothing is loading, and no overlap is in progress. It unbinds auto-advance and cancels
    the overlap trigger. `endEditorHandoff(_:)` re-applies the song state, or reloads if the
    generation changed (the editor added media or switched songs).
  - `SongEditorViewModel.loadSong(context:adoptingPlayback:)` skips the claim/reload.
    `SongDetailView(adoptsPlayback:)` doesn't pause on appear or stop on disappear.
  - Arrangement changes during playback cross-fade per track (`ArrangementSwapFade`: the last
    block on the old map fades out, the new one fades in over 10 ms). The engine ignores an
    arrangement identical to the current one.
  - Mapped keys / MIDI: `InputMappingController` keeps a stack of live sessions, so the editor's
    session (play/pause, stop, loop) takes over from the setlist's and hands back when the editor
    closes. Space plays from the insertion point, which starts where the setlist left the song.
- **Not covered:** the editor on a different song than the loaded one still pauses the setlist.
  An overlap in progress, adding media in the editor, or switching songs in the editor falls back
  to reloading.
- **Tests:** `ArrangementSwapFadeTests`, `InputMappingControllerTests.testNewestLiveSessionGetsActionsUntilItCloses`.

---

## Build 07 – Setlist master meter (2151bbd)

- **Request:** a meter to the right of the setlist like SpaceBear MixReview: peak, RMS, LUFS.
  It should measure the full mix.
- **Change:** a panel on the right of the setlist (macOS) with L/R peak bars (safe / −12 / −6
  zones), a peak-hold line (1 s hold, 20 dB/s fall), an RMS tick, a clip light, and readouts for
  max peak, true peak (dBTP), RMS (300 ms), and momentary / short-term / integrated LUFS. Reset
  clears the integrated reading, the maximums and the clip light. Integrated also resets on each
  new song.
- **What it hears:** the post-fader sum of the music tracks. It leaves out the Click, Cues and
  Timecode groups (by name), groups routed to No Output, and spoken section cues.
- **How:**
  - `MixMeterBus`: a preallocated stereo ring. Each track's render callback adds its post-fader
    block into its own slot. Frames below the slowest track's cursor hold the complete mix. The
    render side is plain memory, with no locks or allocation.
  - `MixMeterSampler` (an actor) reads the ring about 30 times a second off the main actor and
    runs `MixLoudnessAnalyzer`, ported from MixReview's `MonitorUnit` / `Player`: BS.1770
    K-weighting with libebur128 coefficients, 100 ms slices, gated integrated loudness, and 4×
    oversampled true peak with a 48-tap filter.
  - `MixMeterModel` publishes the readings. `SetlistMixMeterView` draws them.
  - Output wiring moved from `AudioEngineManager.swift` to `AudioEngineManager+Wiring.swift` so
    the file shrank instead of growing.
- **Limits:** during an overlap the meter follows the outgoing song until the handoff. Tracks at a
  sample rate different from the majority are not metered.
- **Tests:** `MixLoudnessAnalyzerTests` (a −20 dBFS 997 Hz stereo sine reads −20 LUFS, true peak
  finds inter-sample peaks, ballistics, reset), `MixMeterBusTests`, `MixMeterEngineTests` (real
  engine: music at −20 LUFS, loud click excluded).

---

## Build 06 – Snapping and quick edit (9129072)

### Magnetic snapping
- **Request:** "snapping to the track above or below".
- **Change:** a dragged or trimmed clip edge within 8 points of another clip's edge (any track),
  the playhead, the insertion point, a section marker or the song start jumps onto it, with an
  accent guide line. Otherwise the existing beat-grid snap applies. Holding Control while
  dragging turns all snapping off.
- **Files:** `Services/Editing/ClipSnapping.swift` (pure), `EditView+Snapping.swift`,
  `EditView+Clips.swift`. **Tests:** `ClipSnappingTests`.

### Quick edit of key, tempo and meter from the library
- **Request:** "can't edit key, time signature or meter outside edit mode".
- **Change:** a sliders button on each library row opens a popover for key, starting tempo and
  starting meter. It changes only bar 1; later tempo and meter changes stay. It is hidden for the
  song open in the editor. Rows now show `Key · BPM · meter · tracks`.
- **Files:** `Services/Project/SongMetadataEditor.swift`, `Views/Songs/SongQuickEditPopover.swift`,
  `SongLibraryRow.swift`. **Tests:** `SongMetadataEditorTests`.

---

## Build 05 – Smooth fader and clip drags (2387ece)

- **Request:** the editor's volume fader and clip dragging stuttered the UI.
- **Causes and fixes:**
  - Fader drags wrote the SwiftData model on every tick, which re-rendered the whole editor. Now
    `TrackLaneHeaderView` keeps the drag in local `@State`, sends it straight to the engine, and
    writes the model once on release.
  - Every redraw resolved each track's media bookmark from disk. `SongEditorViewModel.fileURL(for:)`
    now caches by track ID + media path until the song reloads.

---

## Build 04 – Stop default, Song Key, Transpose rename, No Output in the editor (c417fa9)

- New setlist entries default to **Stop** (was Continue). Clearing overlaps also falls back to Stop.
- **Song Key** picker (12 keys + None) in the editor's ⋯ menu. It sets the key the song is written
  in, not a transposition. Undoable, saved to the project file.
- "Change Key" renamed **Transpose** everywhere (menu, dialog, undo name, error).
- **No Output in the editor:** the editor monitors through the master mix until show routing is
  applied, so a group routed to No Output (an imported timecode stem) was still audible there.
  Groups routed to No Output (and ungrouped tracks, when those are) are now silenced in that
  mode, matching the setlist. `AudioEngineManager+Mix.swift` (new; the mix functions moved
  there), `MasterMixSilencedGroups`.

---

## Build 03 – Batch delete and import (0ba86d7)

- Multi-select in the song library (click, Shift, Command). Delete / context menu removes them
  all after one confirmation that lists the songs and the setlists that will lose them.
- Importing a folder that holds only song folders imports each subfolder as a song.
- Double-click or Return opens a song on the Mac (single click selects).
- **Files:** `SongLibraryView.swift`, `SongLibraryRow.swift` (own file now),
  `SongLibraryPanel+Removal.swift`, `SongFolderImporter+Batch.swift`. **Tests:** `SongFolderBatchTests`.

---

## Build 02 – Keys, Insert Bars, editor timecode (b8a4777)

- **Keys:** 12 pitch classes. Black keys display combined ("C#/Db"). `SongMusicalKey(spelling:)`
  accepts any spelling or "X/Y". Raw values are unchanged, so saved songs load as before.
- **Insert Bars:** Edit ▸ Insert Bars… and the ruler / section menus. Inserts whole bars at a
  measure, shifting clips, markers, and later tempo and meter changes (`EditView+InsertBars.swift`,
  `InsertBarsPrompt.swift`). Also "Duplicate Section" on section markers.
- **Editor timecode:** generated LTC is no longer added in the editor until show routing is
  applied (it was playing into the main outs).

---

## Build 01 – Opens on other Macs (a8f7d37) and earlier fixes

- **Fork independence (c7dbda4):** bundle ID `com.spacebear.cues`, ad-hoc signing, no team.
  Sparkle's feed URL comes from `SPARKLE_FEED_URL` (empty), and the updater is skipped when
  it's empty, so the fork never pulls upstream releases.
- **Hardened Runtime off (a8f7d37):** with it on, ad-hoc builds crashed on other Macs (dyld
  "different Team IDs" loading Sparkle.framework). The real app with Developer ID signing
  doesn't need this.
- **Review fixes (67e71a9):** readable text on light group colors (`Color.readableTextColor`);
  the library sort order is remembered; Command + scroll zooms the editor, setlist and overlap
  waveforms; Xcode 27 type-check timeout fixed by splitting `EditView.body`.
- **Setlist clicks without sections (5c39d35):** clicking an unloaded song with no section markers
  starts it at the clicked time.

---

## Ideas for later

- **Show / Edit mode (Josh):** a button at the top right that switches between Show and Edit.
  Show mode locks out things that are risky mid-gig: soloing, routing changes, editing, and so on.
  Not started.

---

## Open issues and notes for Blake

- **Transpose crackles** during playback on Josh's MacBook. On the Mac mini it is clean: one to
  twelve 44.1/48 kHz stereo stems through the real engine showed no dropouts or clicks, and
  16 transposed stereo stems used about a quarter of the audio deadline (2048-frame buffer). The
  likely cause is CPU: Signalsmith Stretch runs per stem on the single render thread, in bursts.
  Options: pre-render transposed stems in the background and cache them (cleanest), or the
  library's cheaper preset (about half the CPU, rougher sound). Paused for Blake.
- **Library database is deleted silently** when it fails to open or when `storeVersion` is bumped
  (`PersistenceController`). Only setlists and the songs in them are re-imported. Songs not in a
  setlist vanish from the library (their files remain in `Documents/cues.live/Songs`), and
  routing, groups and timecode settings reset. Suggested fix: keep a copy instead of deleting,
  re-import every `.cueslive` in the Songs folder, and tell the user what happened. Not done here.
- **Remote PIN** has no rate limiting or lockout.
- **Mixer `isPlaying`** can briefly update out of order.
- **File sizes:** `AudioEngineManager.swift` (~1,070 lines) and `PlaybackCoordinator.swift`
  (~1,060) are still over AGENTS.md's 800-line limit. Changes here added to them only through
  extension files, except one guard line in `setArrangement`.
- **iOS:** builds compile but were not tested; Josh is Mac-only.
