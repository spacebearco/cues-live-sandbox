import SwiftUI

/// Transport, now-playing display, and view toggles for the live setlist window toolbar.
/// Laid out like Logic Pro's control bar: view toggles lead, transport and the song display
/// sit in the centre, and the setlist's own actions trail.
struct LiveSetlistTransportToolbarContent: ToolbarContent {
    let coordinator: PlaybackCoordinator
    let sectionLoop: SectionLoopController
    let groupMixFade: GroupMixFadeController
    let canLoop: Bool
    let isWaveformVisible: Bool
    let isMixerVisible: Bool
    let isEditorOpen: Bool
    var isMeTimeOn = false
    let onStop: () -> Void
    let onToggleLoop: () -> Void
    let onToggleFade: () -> Void
    let onToggleWaveform: () -> Void
    let onToggleMixer: () -> Void
    let onToggleEditor: () -> Void
    var onToggleFilterSweep: () -> Void = {}
    var onToggleMeTime: () -> Void = {}
    var onMeTimeOutputChanged: () -> Void = {}

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: viewTogglePlacement) {
            Toggle(isOn: Binding(get: { isWaveformVisible }, set: { _ in onToggleWaveform() })) {
                Label("Waveform", systemImage: "waveform")
            }
            .help(isWaveformVisible ? "Hide Waveform" : "Show Waveform")

            Toggle(isOn: Binding(get: { isMixerVisible }, set: { _ in onToggleMixer() })) {
                Label("Group Mixer", systemImage: "slider.vertical.3")
            }
            .help("Group Mixer")

            LiveToolbarEditorToggle(
                coordinator: coordinator,
                isOn: isEditorOpen,
                action: onToggleEditor
            )

            #if os(macOS)
            MeTimeToolbarToggle(
                isOn: isMeTimeOn,
                onToggle: onToggleMeTime,
                onOutputChanged: onMeTimeOutputChanged
            )
            #endif
        }

        ToolbarItem(placement: .principal) {
            LiveToolbarTransportControls(
                coordinator: coordinator,
                sectionLoop: sectionLoop,
                groupMixFade: groupMixFade,
                canLoop: canLoop,
                onStop: onStop,
                onToggleLoop: onToggleLoop,
                onToggleFade: onToggleFade,
                onToggleFilterSweep: onToggleFilterSweep
            )
        }

        ToolbarItem(placement: .principal) {
            LiveToolbarNowPlaying(coordinator: coordinator)
        }
        .cuesHideSharedBackground()
    }

    private var viewTogglePlacement: ToolbarItemPlacement {
        #if os(macOS)
        .navigation
        #else
        .topBarLeading
        #endif
    }
}

/// The shared toolbar transport, bound to the setlist's playback. Reads the coordinator itself
/// so playback state changes redraw only the toolbar, not the setlist.
private struct LiveToolbarTransportControls: View {
    let coordinator: PlaybackCoordinator
    let sectionLoop: SectionLoopController
    let groupMixFade: GroupMixFadeController
    let canLoop: Bool
    let onStop: () -> Void
    let onToggleLoop: () -> Void
    let onToggleFade: () -> Void
    let onToggleFilterSweep: () -> Void

    var body: some View {
        ToolbarTransportControls(
            isPlaying: coordinator.isPlaying,
            isLoaded: coordinator.isLoaded && !coordinator.isLoadingSong,
            isLooping: sectionLoop.isLooping,
            canLoop: canLoop,
            isFadedOut: groupMixFade.isFadedOut,
            isFading: groupMixFade.isFading,
            onStop: onStop,
            onPlayPause: togglePlayback,
            onToggleFade: onToggleFade,
            onToggleLoop: onToggleLoop,
            filterSweep: ToolbarTransportControls.FilterSweep(
                isOn: groupMixFade.isFilterSwept,
                isEnabled: !groupMixFade.isFadedOut && !groupMixFade.isFading,
                toggle: onToggleFilterSweep
            )
        )
    }

    private func togglePlayback() {
        if coordinator.isPlaying {
            coordinator.pause()
        } else {
            coordinator.play()
        }
    }
}

/// The playing song and what is up next, centred beside the transport.
private struct LiveToolbarNowPlaying: View {
    let coordinator: PlaybackCoordinator

    var body: some View {
        LiveToolbarSongTitle(
            title: coordinator.currentSong?.name ?? "Not Playing",
            upNext: coordinator.nextSong?.name
        )
        .frame(minWidth: 160, maxWidth: 320)
        .accessibilityElement(children: .combine)
    }
}

/// Opens the song editor on the playing song (Command-E). Disabled while nothing is loaded,
/// and hidden in Show mode, where editing is locked.
private struct LiveToolbarEditorToggle: View {
    let coordinator: PlaybackCoordinator
    let isOn: Bool
    let action: () -> Void
    @AppStorage(SetlistPlayMode.storageKey) private var playMode = SetlistPlayMode.defaultMode

    var body: some View {
        if playMode == .edit {
            Toggle(isOn: Binding(get: { isOn }, set: { _ in action() })) {
                Label("Song Editor", systemImage: "rectangle.badge.plus")
            }
            .disabled(coordinator.currentSong == nil)
            .keyboardShortcut("e", modifiers: .command)
            .help("Edit the playing song (⌘E)")
        }
    }
}
