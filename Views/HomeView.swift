import SwiftUI

/// Start menu. Laid out for landscape — the app is landscape-only, so this is a
/// wide, short canvas (roughly 874 × 402 on an iPhone) rather than a tall column.
/// Title across the top, the two ways in side by side beneath it.
struct HomeView: View {
    @State private var showMatch = false
    @State private var showCollection = false

    private var cardsWithArt: Int {
        CardLibrary.all.filter { UIImage(named: $0.id) != nil }.count
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 420      // phone landscape
            ZStack {
                Backdrop()

                VStack(spacing: 0) {
                    title(compact: compact)
                        .padding(.top, compact ? 18 : 44)

                    Spacer(minLength: 8)

                    HStack(spacing: 16) {
                        HomeButton(title: "Co-op Play",
                                   subtitle: "2 players · pass and play",
                                   icon: "flag.checkered",
                                   compact: compact) { showMatch = true }

                        HomeButton(title: "Collection",
                                   subtitle: "\(cardsWithArt) of \(CardLibrary.all.count) cards",
                                   icon: "square.grid.2x2.fill",
                                   compact: compact) { showCollection = true }
                    }
                    .padding(.horizontal, compact ? 40 : 80)

                    Spacer(minLength: 8)

                    HStack(spacing: 30) {
                        stat("Creatures", CardLibrary.creatures.count)
                        stat("Humans", CardLibrary.humans.count)
                        stat("Relics", CardLibrary.relics.count)
                        stat("Events", CardLibrary.events.count)
                    }
                    .padding(.bottom, compact ? 16 : 34)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .statusBarHidden()
        .fullScreenCover(isPresented: $showMatch) { TCGMatchView() }
        .fullScreenCover(isPresented: $showCollection) { CardCollectionView() }
    }

    private func title(compact: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "flag.checkered")
                .font(.system(size: compact ? 26 : 38))
                .foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("SHEPHERD TCG")
                    .font(.system(size: compact ? 28 : 38, weight: .bold, design: .serif))
                    .tracking(2)
                    .foregroundStyle(Theme.text)
                Text("Race to the Promised Land")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(Theme.text.opacity(0.5))
            }
        }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title3.bold()).foregroundStyle(Theme.text)
            Text(label.uppercased()).font(.caption2).foregroundStyle(Theme.text.opacity(0.4))
        }
    }
}

/// One way into the game. Two of these sit side by side, so it's a squarish card
/// rather than the full-width row the portrait menu used.
private struct HomeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: compact ? 6 : 10) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 26 : 34, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(compact ? .title3.bold() : .title2.bold())
                Text(subtitle)
                    .font(.caption)
                    .opacity(0.75)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 16 : 26)
            .padding(.horizontal, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.bark, lineWidth: 1.5)
            )
        }
    }
}
