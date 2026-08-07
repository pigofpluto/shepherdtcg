import SwiftUI

/// Clearing an Event turns one of your face-down Relics over — this asks which.
///
/// Both are shown **face-up**, because otherwise the choice would be blind: decks
/// are generated randomly, so a player has no way of knowing what they set aside.
/// Seeing both and picking one is the decision; the other stays hidden until the
/// next Event clear.
///
/// This is the game's first player-choice UI. The engine suspends on a
/// continuation while it's open (see `MatchViewModel.unlockRelic`), which is the
/// same shape that player-chosen targeting would need.
struct RelicChooser: View {
    let choice: MatchViewModel.RelicChoice
    let onPick: (CardInstance) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: geo.size.height * 0.04) {
                    VStack(spacing: 4) {
                        Text("Event overcome")
                            .font(.caption).tracking(1.5)
                            .foregroundStyle(Theme.gold.opacity(0.85))
                        Text("Choose a Relic to unlock")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: geo.size.width * 0.03) {
                        ForEach(choice.options) { inst in
                            Button { onPick(inst) } label: {
                                TCGCardView(card: inst.card)
                                    .frame(height: geo.size.height * 0.62)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Theme.gold.opacity(0.55), lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("The other stays face-down until your next Event.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.vertical, 16)
        }
        .transition(.opacity)
    }
}
