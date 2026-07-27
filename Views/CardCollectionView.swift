import SwiftUI

/// Browsable gallery of the full 87-card Bible-TCG set. Filter by type and
/// discipline/element; tap a card to see it enlarged with its full rules text.
struct CardCollectionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var typeFilter: TypeFilter = .all
    @State private var attributeFilter: AttributeFilter = .all
    @State private var selected: TCGCard?

    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    private var filtered: [TCGCard] {
        CardLibrary.all.filter { card in
            // Only show cards that actually have art imported yet.
            guard UIImage(named: card.id) != nil else { return false }
            return typeFilter.matches(card) && attributeFilter.matches(card)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop()
                VStack(spacing: 12) {
                    filterBar

                    Text("\(filtered.count) card\(filtered.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(Theme.text.opacity(0.5))

                    if filtered.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle).foregroundStyle(Theme.text.opacity(0.3))
                            Text("No cards with art yet")
                                .font(.subheadline).foregroundStyle(Theme.text.opacity(0.5))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(filtered) { card in
                                    Button { selected = card } label: {
                                        TCGCardView(card: card)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.text)
                }
            }
            .sheet(item: $selected) { card in
                CardDetailView(card: card)
                    .presentationDetents([.large])
            }
        }
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            Picker("Type", selection: $typeFilter) {
                ForEach(TypeFilter.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AttributeFilter.allCases, id: \.self) { f in
                        let isOn = attributeFilter == f
                        Button { attributeFilter = f } label: {
                            Text(f.label)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(isOn ? f.color.opacity(0.85) : Theme.panel(0.08),
                                            in: Capsule())
                                .foregroundStyle(isOn ? .white : Theme.text.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Detail

private struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let card: TCGCard

    var body: some View {
        ZStack {
            Backdrop()
            ScrollView {
                VStack(spacing: 20) {
                    TCGCardView(card: card)
                        .frame(maxWidth: 300)
                        .padding(.top, 24)

                    VStack(spacing: 14) {
                        infoRow("Type", card.type.displayName)
                        if card.type.hasStats {
                            infoRow("Attack / Health", "\(card.attack) / \(card.health)")
                            infoRow("Mana Cost", "\(card.cost)")
                        } else if card.type == .relic {
                            infoRow("Mana Cost", "\(card.cost)")
                        }
                        if let cat = card.discipline {
                            infoRow("Discipline", cat.displayName)
                        }
                        if let el = card.element {
                            infoRow("Element", el.displayName)
                        }
                        if !card.keywords.isEmpty {
                            infoRow("Keywords", card.keywords.map { $0.capitalized }.joined(separator: ", "))
                        }
                        if card.type == .event {
                            infoRow("Requirement", card.requirement
                                .map { "\($0.count) \($0.element.displayName)" }
                                .joined(separator: ", "))
                        }

                        if !card.ability.isEmpty {
                            textBlock(card.type == .relic ? "Relic" : "Ability", card.ability)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2).foregroundStyle(Theme.text.opacity(0.5))
            }
            .padding(16)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.text.opacity(0.45))
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(Theme.text)
        }
    }

    private func textBlock(_ label: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold)).foregroundStyle(card.accent.opacity(0.9))
            Text(body)
                .font(.callout).foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Theme.panel(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Filters

private enum TypeFilter: CaseIterable, Hashable {
    case all, human, creature, event, relic

    var label: String {
        switch self {
        case .all:      return "All"
        case .human:    return "Human"
        case .creature: return "Creature"
        case .event:    return "Event"
        case .relic:    return "Relic"
        }
    }

    func matches(_ card: TCGCard) -> Bool {
        switch self {
        case .all:      return true
        case .human:    return card.type == .human
        case .creature: return card.type == .creature
        case .event:    return card.type == .event
        case .relic:    return card.type == .relic
        }
    }
}

/// Filters by human discipline (Wisdom/Courage/Strength) or creature element (Air/Sea/Land).
private enum AttributeFilter: Hashable, CaseIterable {
    case all
    case discipline(Discipline)
    case element(Element)

    static var allCases: [AttributeFilter] {
        [.all] + Discipline.allCases.map { .discipline($0) } + Element.allCases.map { .element($0) }
    }

    var label: String {
        switch self {
        case .all:                return "Any"
        case .discipline(let c):  return c.displayName
        case .element(let e):     return e.displayName
        }
    }

    var color: Color {
        switch self {
        case .all:                return Theme.sage
        case .discipline(let c):  return c.color
        case .element(let e):     return e.color
        }
    }

    func matches(_ card: TCGCard) -> Bool {
        switch self {
        case .all:                return true
        case .discipline(let c):  return card.discipline == c
        case .element(let e):     return card.element == e
        }
    }
}
