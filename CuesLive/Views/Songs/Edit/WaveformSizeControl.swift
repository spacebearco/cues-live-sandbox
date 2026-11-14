import SwiftUI

/// Remembers each song's waveform size in the editor. Songs never set draw at 1×.
enum WaveformSizeStore {
    static let range: ClosedRange<Double> = 0.5...4
    private static let key = "editorWaveformScaleBySong"

    static func scale(for songID: UUID) -> Double {
        let stored = (UserDefaults.standard.dictionary(forKey: key) as? [String: Double])?[songID.uuidString]
        return stored.map { min(max($0, range.lowerBound), range.upperBound) } ?? 1
    }

    static func setScale(_ scale: Double, for songID: UUID) {
        var all = (UserDefaults.standard.dictionary(forKey: key) as? [String: Double]) ?? [:]
        all[songID.uuidString] = scale == 1 ? nil : scale
        UserDefaults.standard.set(all, forKey: key)
    }
}

/// Like Logic's waveform zoom: draws this song's waveforms taller or shorter inside their
/// clips without changing track heights or the audio.
struct WaveformSizeControl: View {
    @Binding var scale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("Waveform Size")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f×", scale))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppColors.textSecondary)
            }
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                Slider(value: $scale, in: WaveformSizeStore.range)
                Image(systemName: "waveform")
                    .font(.body)
                    .foregroundStyle(AppColors.textTertiary)
            }
            HStack {
                Text("For this song.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
                Button("Reset") { scale = 1 }
                    .controlSize(.small)
                    .disabled(scale == 1)
            }
        }
        .padding(AppSpacing.md)
        .frame(width: 280)
    }
}
