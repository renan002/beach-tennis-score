import SwiftUI

/// The single purchase surface of the app, presentable from anywhere on the
/// iPhone — the locked Statistics screen, the Cartão watermark, and the locked
/// Multiple option all present *this* sheet rather than growing their own.
///
/// It sells; it does not gate. Gating is a plain `isPro ? … : …` at each
/// touchpoint (this ticket ships none of them yet).
struct ProPurchaseSheet: View {
    /// The one-line pitch, shared with the Settings section's footer so the
    /// promise is worded once.
    static func pitch(isPro: Bool) -> LocalizedStringKey {
        isPro
            ? "Thanks for supporting the app."
            : "One purchase, yours forever. No subscription."
    }

    @EnvironmentObject private var pro: ProEntitlement
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseFailure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    features
                    if !pro.isPro { actions }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Purchase failed",
                isPresented: Binding(
                    get: { purchaseFailure != nil },
                    set: { if !$0 { purchaseFailure = nil } }
                )
            ) {
                Button("Done") { purchaseFailure = nil }
            } message: {
                Text(purchaseFailure ?? "")
            }
            .task { await pro.loadProduct() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: pro.isPro ? "checkmark.seal.fill" : "star.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(pro.isPro ? "Pro unlocked" : "Unlock Pro")
                .font(.title2.bold())
            Text(Self.pitch(isPro: pro.isPro))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var features: some View {
        VStack(alignment: .leading, spacing: 16) {
            feature(
                icon: "chart.bar.xaxis",
                title: "Statistics",
                detail: "See what your Match History says about your play"
            )
            feature(
                icon: "photo.on.rectangle.angled",
                title: "Result Card without watermark",
                detail: "Share your result with nothing but the match on it"
            )
            feature(
                icon: "figure.tennis",
                title: "Multiple",
                // The Settings picker's own footer, reused verbatim: one
                // sentence, one catalog key, one translation to keep true.
                detail: "The Watch will ask which sport before each match."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feature(
        icon: String,
        title: LocalizedStringKey,
        detail: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    switch await pro.purchase() {
                    // A completed purchase has made its own point; the sheet
                    // gets out of the way. Ask to Buy leaves it up, since the
                    // unlock lands later through the transaction listener.
                    case .purchased:              dismiss()
                    case .failed(let message):    purchaseFailure = message
                    case .pending, .cancelled, .busy: break
                    }
                }
            } label: {
                Group {
                    if pro.isPurchasing {
                        ProgressView()
                    } else {
                        Text(purchaseButtonTitle)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(pro.isPurchasing || pro.isRestoring)

            RestorePurchasesButton()

            Text("Scoring, Match History and the Result Card stay free.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// The store's own localized, currency-correct price — never one we
    /// hardcode, so a price change in App Store Connect needs no release. Falls
    /// back to the price-free title while the product is still loading.
    private var purchaseButtonTitle: String {
        guard let price = pro.product?.displayPrice else {
            return String(localized: "Unlock Pro")
        }
        return String(localized: "Unlock Pro — \(price)")
    }
}
