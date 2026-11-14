import Foundation

/// Pitch-class root key for a song. Displayed key is this value shifted by `transposeSemitones`.
///
/// There is one case per semitone. Black keys are shown with both spellings
/// ("C#/Db") so a song reads correctly whichever chart it comes from. Raw values
/// keep the original single spellings so stored songs and project files stay compatible.
enum SongMusicalKey: String, CaseIterable, Codable, Hashable, Sendable {
    case c = "C"
    case cSharp = "C#"
    case d = "D"
    case eFlat = "Eb"
    case e = "E"
    case f = "F"
    case fSharp = "F#"
    case g = "G"
    case aFlat = "Ab"
    case a = "A"
    case bFlat = "Bb"
    case b = "B"

    /// Chromatic order from C through B.
    static let chromaticOrder: [SongMusicalKey] = [
        .c, .cSharp, .d, .eFlat, .e, .f, .fSharp, .g, .aFlat, .a, .bFlat, .b
    ]

    /// Every spelling a stored or imported key may use, mapped to its pitch class.
    private static let spellings: [String: SongMusicalKey] = [
        "C": .c, "B#": .c,
        "C#": .cSharp, "Db": .cSharp,
        "D": .d,
        "D#": .eFlat, "Eb": .eFlat,
        "E": .e, "Fb": .e,
        "F": .f, "E#": .f,
        "F#": .fSharp, "Gb": .fSharp,
        "G": .g,
        "G#": .aFlat, "Ab": .aFlat,
        "A": .a,
        "A#": .bFlat, "Bb": .bFlat,
        "B": .b, "Cb": .b,
    ]

    /// Reads any spelling ("Db", "C#", "C#/Db"), or `nil` when it is not a key.
    init?(spelling: String) {
        let trimmed = spelling.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = trimmed.split(separator: "/").first.map(String.init) ?? trimmed
        guard let key = Self.spellings[first] else { return nil }
        self = key
    }

    var displayName: String {
        switch self {
        case .cSharp: return "C#/Db"
        case .eFlat: return "D#/Eb"
        case .fSharp: return "F#/Gb"
        case .aFlat: return "G#/Ab"
        case .bFlat: return "A#/Bb"
        default: return rawValue
        }
    }

    var semitoneIndex: Int {
        Self.chromaticOrder.firstIndex(of: self) ?? 0
    }

    static func from(semitoneIndex: Int) -> SongMusicalKey {
        let wrapped = ((semitoneIndex % 12) + 12) % 12
        return chromaticOrder[wrapped]
    }

    func transposed(by semitones: Int) -> SongMusicalKey {
        Self.from(semitoneIndex: semitoneIndex + semitones)
    }

    /// Compact label such as `G` or `Am`.
    func label(mode: SongKeyMode) -> String {
        displayName + mode.symbolSuffix
    }

    /// Key label for badges, or `nil` when no base key is set.
    static func display(baseRaw: String?, modeRaw: String? = nil, transposeSemitones: Int = 0) -> String? {
        guard let baseRaw, let base = SongMusicalKey(spelling: baseRaw) else { return nil }
        return base.transposed(by: transposeSemitones).label(mode: SongKeyMode(raw: modeRaw))
    }

    /// Transport readout text (`—` when unset).
    static func transportText(baseRaw: String?, modeRaw: String? = nil, transposeSemitones: Int = 0) -> String {
        display(baseRaw: baseRaw, modeRaw: modeRaw, transposeSemitones: transposeSemitones) ?? "—"
    }
}

extension Song {
    var displayedKeyText: String? {
        SongMusicalKey.display(baseRaw: baseKeyRaw, modeRaw: keyModeRaw, transposeSemitones: transposeSemitones)
    }

    var transportKeyText: String {
        SongMusicalKey.transportText(baseRaw: baseKeyRaw, modeRaw: keyModeRaw, transposeSemitones: transposeSemitones)
    }
}
