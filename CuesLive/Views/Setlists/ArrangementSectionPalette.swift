import SwiftUI

/// Rotating fill/accent pairs that give each arrangement section its own color in the live waveform.
enum ArrangementSectionPalette {
    /// Saturated section fills — clear section identity without overpowering the waveform.
    private static let pairs: [(background: Color, accent: Color)] = [
        (Color(.arrangementSection1Background), Color(.arrangementSection1Accent)),
        (Color(.arrangementSection2Background), Color(.arrangementSection2Accent)),
        (Color(.arrangementSection3Background), Color(.arrangementSection3Accent)),
        (Color(.arrangementSection4Background), Color(.arrangementSection4Accent)),
        (Color(.arrangementSection5Background), Color(.arrangementSection5Accent)),
        (Color(.arrangementSection6Background), Color(.arrangementSection6Accent)),
        (Color(.arrangementSection7Background), Color(.arrangementSection7Accent)),
        (Color(.arrangementSection8Background), Color(.arrangementSection8Accent)),
        (Color(.arrangementSection9Background), Color(.arrangementSection9Accent)),
    ]

    /// Names for the colors, in palette order, for pickers.
    static let names = ["Blue", "Yellow", "Orange", "Pink", "Teal", "Purple", "Green", "Red", "Gray"]
    /// Sections without a picked color cycle through the first six, as they always have.
    private static let automaticCount = 6

    static let backgroundFillOpacity: Double = 0.30
    static let backgroundCueFillOpacity: Double = 0.48

    /// The picked color when there is one, otherwise the automatic color for the section's position.
    static func colors(for index: Int, picked: Int? = nil) -> (background: Color, accent: Color) {
        if let picked, pairs.indices.contains(picked) {
            return pairs[picked]
        }
        return pairs[index % automaticCount]
    }
}
