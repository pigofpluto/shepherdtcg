import SwiftUI

struct HomeView: View {
    @State private var showMatch = false
    @State private var showCollection = false

    private var cardsWithArt: Int {
        CardLibrary.all.filter { UIImage(named: $0.id) != nil }.count
    }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.gold)
                    Text("BIBLE TCG")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(Theme.text)
                    Text("Race to the Promised Land")
                        .font(.subheadline)
                        .foregroundStyle(Theme.text.opacity(0.5))
                }
                .padding(.top, 60)

                Spacer()

                VStack(spacing: 16) {
                    HomeButton(title: "Play",
                               subtitle: "2 players · pass and play",
                               icon: "flag.checkered") { showMatch = true }

                    HomeButton(title: "Collection",
                               subtitle: "\(cardsWithArt) of \(CardLibrary.all.count) cards",
                               icon: "square.grid.2x2.fill") { showCollection = true }
                }
                .padding(.horizontal, 24)

                Spacer()

                HStack(spacing: 26) {
                    stat("Creatures", CardLibrary.creatures.count)
                    stat("Humans", CardLibrary.humans.count)
                    stat("Relics", CardLibrary.relics.count)
                    stat("Events", CardLibrary.events.count)
                }
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showMatch) { TCGMatchView() }
        .fullScreenCover(isPresented: $showCollection) { CardCollectionView() }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title3.bold()).foregroundStyle(Theme.text)
            Text(label.uppercased()).font(.caption2).foregroundStyle(Theme.text.opacity(0.4))
        }
    }
}

private struct HomeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.title2.bold())
                    Text(subtitle).font(.caption).opacity(0.9)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.headline).opacity(0.7)
            }
            .foregroundStyle(Theme.text)
            .padding(.vertical, 20)
            .padding(.horizontal, 22)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.bark, lineWidth: 1.5)
            )
        }
    }
}
