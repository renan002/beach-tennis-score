import SwiftUI

/// Restore Purchases, in one place: Settings offers it (where a buyer on a new
/// iPhone looks for it) and the purchase sheet offers it (where App Review
/// expects it), and both get the same button, the same disabled states and the
/// same answer.
///
/// The answer is owned here rather than on `ProEntitlement`: the outcome
/// belongs to the tap that caused it, so a failure in Settings can never
/// surface as an alert on the sheet later.
struct RestorePurchasesButton: View {
    @EnvironmentObject private var pro: ProEntitlement
    @State private var outcome: ProEntitlement.RestoreOutcome?

    var body: some View {
        Button("Restore Purchases") {
            Task {
                let result = await pro.restore()
                // Nothing to say about a cancelled sign-in or a double tap.
                if result != .cancelled && result != .busy { outcome = result }
            }
        }
        .disabled(pro.isRestoring || pro.isPurchasing)
        .alert(alertTitle, isPresented: isPresented) {
            Button("Done") { outcome = nil }
        } message: {
            alertMessage
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { outcome != nil },
            set: { if !$0 { outcome = nil } }
        )
    }

    private var alertTitle: LocalizedStringKey {
        switch outcome {
        case .restored:         return "Pro unlocked"
        case .nothingToRestore: return "Nothing to restore"
        default:                return "Restore failed"
        }
    }

    @ViewBuilder
    private var alertMessage: some View {
        switch outcome {
        case .restored:
            Text("Your purchase was restored.")
        case .nothingToRestore:
            Text("This Apple Account has no Pro purchase to restore.")
        case .failed(let message):
            // StoreKit's own words: it knows whether this was the network, the
            // account, or the store, and we do not.
            Text(message)
        default:
            EmptyView()
        }
    }
}
