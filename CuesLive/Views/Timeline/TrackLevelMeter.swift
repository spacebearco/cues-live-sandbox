import SwiftUI

/// A track's stereo level beside its header: left and right bars. In each, the solid part is RMS
/// (how loud it sounds) and the lighter part above reaches the sample peak, which turns yellow
/// above -6 dB and red at full scale. Scale is -60…0 dB. Updates while the editor's meter
/// timer runs.
struct TrackLevelMeter: View {
    let trackID: UUID
    @Bindable private var audioEngine = AudioEngineManager.shared

    static let width: CGFloat = 7
    private static let floorDB: Float = -60

    var body: some View {
        // Reading the observed peak redraws this on every meter refresh.
        _ = audioEngine.trackMeterLevels[trackID]
        let levels = audioEngine.trackStereoLevels(id: trackID)
        return HStack(spacing: 1) {
            bar(peak: levels.peakLeft, rms: levels.rmsLeft)
            bar(peak: levels.peakRight, rms: levels.rmsRight)
        }
        .frame(width: Self.width)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func bar(peak: Float, rms: Float) -> some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            ZStack(alignment: .bottom) {
                Rectangle().fill(AppColors.surface)
                Rectangle()
                    .fill(peakColor(peak).opacity(0.45))
                    .frame(height: height * Self.fraction(peak))
                Rectangle()
                    .fill(AppColors.Mixer.meterLevel)
                    .frame(height: height * Self.fraction(rms))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
    }

    private func peakColor(_ level: Float) -> Color {
        if level >= 0.999 { return AppColors.Mixer.meterOver }
        if level >= 0.5 { return AppColors.Mixer.meterWarning }
        return AppColors.Mixer.meterLevel
    }

    /// Height fraction for a linear level on the -60…0 dB scale.
    static func fraction(_ level: Float) -> CGFloat {
        guard level > 0 else { return 0 }
        let decibels = 20 * log10(level)
        return CGFloat(min(1, max(0, (decibels - floorDB) / -floorDB)))
    }
}
