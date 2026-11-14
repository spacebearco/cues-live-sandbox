import SwiftUI

/// Asks how many empty bars to open up at a bar line. Everything from that bar on
/// (clips, section markers, MIDI, and later tempo or meter changes) moves later.
struct InsertBarsPrompt: View {
    static let barRange = 1...64

    let measure: Int
    let onCancel: () -> Void
    let onInsert: (_ barCount: Int) -> Void

    @State private var barCount = 4

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $barCount, in: Self.barRange) {
                        Text(barCount == 1 ? "1 bar" : "\(barCount) bars")
                            .monospacedDigit()
                    }
                } header: {
                    Text("Insert empty bars before measure \(measure)")
                } footer: {
                    Text("Everything from measure \(measure) on moves later. To repeat a part instead, right-click its section marker and choose Duplicate Section.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Insert Bars")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") { onInsert(barCount) }
                }
            }
        }
        .standardDialogToolbar()
        .frame(minWidth: 360, minHeight: 200)
    }
}
