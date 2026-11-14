import SwiftData
import SwiftUI

/// The setlist's master meter: peak and RMS bars with hold lines, then true peak, RMS and
/// momentary, short-term and integrated loudness. It measures the music tracks only, leaving
/// out click, cues and timecode, and starts the integrated reading over for each song.
@MainActor
struct SetlistMixMeterView: View {
    static let width: CGFloat = 132

    let model: MixMeterModel
    let engine: AudioEngineManager

    @Query(sort: \TrackGroup.sortOrder) private var groups: [TrackGroup]

    private var excludedGroupIDs: Set<UUID> {
        AudioEngineManager.mixMeterExcludedGroupIDs(in: groups)
    }

    var body: some View {
        let readings = model.readings
        VStack(spacing: AppSpacing.sm) {
            clipLight(readings.hasClipped)
            HStack(alignment: .bottom, spacing: 3) {
                MixMeterBar(peak: readings.peakLeft, hold: readings.holdLeft, rms: readings.rms)
                MixMeterBar(peak: readings.peakRight, hold: readings.holdRight, rms: readings.rms)
                MixMeterScale()
            }
            .frame(maxHeight: .infinity)
            readingsTable(readings)
            Button("Reset") { model.resetMeasurement() }
                .controlSize(.small)
                .help("Start the integrated loudness, maximum peaks and clip light over")
        }
        .padding(AppSpacing.sm)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
        .task(id: ObjectIdentifier(engine)) {
            engine.setMixMeterExcludedGroups(excludedGroupIDs)
            await model.run(on: engine)
        }
        .onChange(of: excludedGroupIDs) { _, ids in
            engine.setMixMeterExcludedGroups(ids)
        }
    }

    /// Lights when a sample reaches full scale. Clicking it resets the meter.
    private func clipLight(_ hasClipped: Bool) -> some View {
        Button {
            model.resetMeasurement()
        } label: {
            Text("CLIP")
                .font(.caption2.weight(.bold))
                .foregroundStyle(hasClipped ? Color.white : AppColors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(hasClipped ? AppColors.Mixer.meterOver : AppColors.surface)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("A sample reached full scale. Click to reset.")
    }

    private func readingsTable(_ readings: MixMeterReadings) -> some View {
        Grid(alignment: .leading, horizontalSpacing: AppSpacing.xs, verticalSpacing: 2) {
            readingRow("Peak", readings.maxPeak, unit: "dB", warnAbove: -1)
            readingRow("TP", readings.truePeak, unit: "dBTP", warnAbove: -1)
            readingRow("RMS", readings.rms, unit: "dB")
            Divider().gridCellColumns(3)
            readingRow("M", readings.momentary, unit: "LUFS")
            readingRow("S", readings.shortTerm, unit: "LUFS")
            readingRow("I", readings.integrated, unit: "LUFS")
        }
        .font(.caption.monospacedDigit())
    }

    private func readingRow(_ label: String, _ value: Double, unit: String, warnAbove: Double? = nil) -> some View {
        let isWarning = warnAbove.map { value > $0 } ?? false
        return GridRow {
            Text(label)
                .foregroundStyle(AppColors.textSecondary)
            Text(Self.format(value))
                .foregroundStyle(isWarning ? AppColors.Mixer.meterOver : AppColors.textPrimary)
                .gridColumnAlignment(.trailing)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    private static func format(_ value: Double) -> String {
        value <= -70 ? "–∞" : String(format: "%.1f", value)
    }
}

/// One channel: the peak bar in safe, warning and over zones, a hold line, and an RMS tick.
private struct MixMeterBar: View {
    let peak: Double
    let hold: Double
    let rms: Double

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            ZStack(alignment: .bottom) {
                Rectangle().fill(AppColors.surface)
                LinearGradient(
                    stops: [
                        .init(color: AppColors.Mixer.meterLevel, location: 0),
                        .init(color: AppColors.Mixer.meterLevel, location: MixMeterScale.fraction(-12)),
                        .init(color: AppColors.Mixer.meterWarning, location: MixMeterScale.fraction(-6)),
                        .init(color: AppColors.Mixer.meterOver, location: 1),
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: height * MixMeterScale.fraction(peak))
                }
                Rectangle()
                    .fill(AppColors.textPrimary)
                    .frame(height: 2)
                    .offset(y: -height * MixMeterScale.fraction(hold))
                    .opacity(hold > MixMeterScale.bottom ? 1 : 0)
                Rectangle()
                    .fill(AppColors.textPrimary.opacity(0.5))
                    .frame(height: 1)
                    .offset(y: -height * MixMeterScale.fraction(rms))
                    .opacity(rms > MixMeterScale.bottom ? 1 : 0)
            }
        }
        .frame(width: 14)
    }
}

/// dB marks beside the bars, on the same scale.
private struct MixMeterScale: View {
    static let bottom: Double = -60
    private static let marks: [Double] = [0, -6, -12, -18, -24, -36, -48, -60]

    /// Height fraction for a level, linear in dB from -60 to 0.
    static func fraction(_ decibels: Double) -> CGFloat {
        CGFloat(min(1, max(0, (decibels - bottom) / -bottom)))
    }

    var body: some View {
        GeometryReader { proxy in
            ForEach(Self.marks, id: \.self) { mark in
                Text(mark == 0 ? "0" : "\(Int(mark))")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(AppColors.textTertiary)
                    .position(x: 12, y: proxy.size.height * (1 - Self.fraction(mark)))
            }
        }
        .frame(width: 24)
    }
}
