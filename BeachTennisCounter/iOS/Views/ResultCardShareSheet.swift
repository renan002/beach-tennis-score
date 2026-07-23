import SwiftUI

/// The share flow's shell: a live preview of the Cartão in the shape the player
/// picked, a segmented control to switch between the square and the Stories
/// shape, and the share action. The chosen shape is persisted, so it is
/// remembered between shares and across launches; every value shown still comes
/// from the `ResultCard` model, and the two shapes are the one `ResultCardView`
/// design at two sizes.
struct ResultCardShareSheet: View {
    let match: StoredMatch
    let teamAColor: Color
    let teamBColor: Color

    /// The persisted shape token, decoded through `CardShape.stored` so an empty
    /// value on first use — or one written by a newer build — lands on the
    /// default rather than crashing the share flow. Not a `CardShape` directly:
    /// `@AppStorage` stores the raw `String`, which is also the storage key.
    @AppStorage("cartaoShape") private var storedShape = CardShape.default.rawValue
    @Environment(\.dismiss) private var dismiss

    private var shape: CardShape { CardShape.stored(storedShape) }

    /// The card model, built once from the stored match and shared by the
    /// preview and the share action so the two can never describe it differently.
    private var card: ResultCard { ResultCard(match: match) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                preview
                shapePicker
                shareButton
            }
            .padding()
            .navigationTitle("Result Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// The card at its true canvas, scaled down to fit the space — so what the
    /// player sees is exactly what will be shared, in the shape they picked.
    private var preview: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / shape.canvasSize.width,
                            geo.size.height / shape.canvasSize.height)
            ResultCardView(
                card: card,
                teamAColor: teamAColor,
                teamBColor: teamBColor,
                sport: match.matchType,
                shape: shape
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(scale)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.default, value: shape)
    }

    private var shapePicker: some View {
        // Tags are the raw tokens the binding persists — never the localized
        // labels. "Stories" is a brand term and carries no catalog entry.
        // "Format" is hidden from the layout but kept as the control's
        // accessibility label, so VoiceOver still announces what the segments
        // choose.
        Picker(selection: $storedShape) {
            Text("Square").tag(CardShape.square.rawValue)
            Text("Stories").tag(CardShape.stories.rawValue)
        } label: {
            Text("Format")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var shareButton: some View {
        // `message:` is already-localized plain text, so it goes in verbatim —
        // a second String Catalog lookup would miss.
        ShareLink(
            item: shareable,
            message: Text(verbatim: ResultCard.shareMessage),
            preview: SharePreview(Text("Result Card"))
        ) {
            Label("Share Result Card", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    /// Built from the stored match alone — no network, no screenshot — so a
    /// match recorded before this feature shipped shares exactly like a fresh
    /// one, offline, in either shape.
    private var shareable: ShareableResultCard {
        ShareableResultCard(
            card: card,
            teamAColor: teamAColor,
            teamBColor: teamBColor,
            sport: match.matchType,
            shape: shape
        )
    }
}
