import SwiftUI

/// A track's level beside its header: the solid bar is RMS (how loud it sounds), the lighter bar
/// above it reaches the sample peak, which turns yellow above -6 dB and red at full scale.
/// Scale is -60…0 dB. Updates while the editor's meter timer runs.
struct TrackLevelMeter: View {
    let trackID: UUID
    @Bindable private var audioEngine = AudioEngineManager.shared

    static let width: CGFloat = 5
    private static let floorDB: Float = -60

    var body: some View {
        let peak = audioEngine.trackMeterLevels[trackID] ?? 0
        let rms = audioEngine.trackRMSLevel(id: trackID)
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
        .frame(width: Self.width)
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
