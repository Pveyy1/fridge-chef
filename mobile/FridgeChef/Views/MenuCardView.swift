import SwiftUI

struct MenuCardView: View {
    @Environment(AppState.self) private var state
    @AppStorage("chefName") private var name = ""
    @State private var shareImage: Image?

    var body: some View {
        if let dish = state.chosen {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Step 5 · Your menu card")
                        TextField("Your name", text: $name)
                            .textInputAutocapitalization(.words)
                            .fieldStyle()
                    }

                    MenuCard(name: name, dish: dish, when: state.whenLabel, course: state.courseLabel)
                        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                    Text("Screenshot it, or share it straight from here.")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)

                    if let shareImage {
                        ShareLink(item: shareImage,
                                  preview: SharePreview("Tonight at \(MenuCard.ownerTitle(name))", image: shareImage)) {
                            Label("Share menu card", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                    TodayLog()

                    Button("Cook something else") { state.startOver() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { render(dish) }
            .onChange(of: name) { _, _ in render(dish) }
        }
    }

    @MainActor
    private func render(_ dish: Dish) {
        let renderer = ImageRenderer(content:
            MenuCard(name: name, dish: dish, when: state.whenLabel, course: state.courseLabel).frame(width: 360).padding(24).background(Color(white: 0.96))
        )
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }
}

struct MenuCard: View {
    let name: String
    let dish: Dish
    var when: String = "TONIGHT AT"
    var course: String = "MAIN COURSE"

    private var owner: String { Self.ownerTitle(name) }

    static func ownerTitle(_ name: String) -> String {
        let n = name.trimmingCharacters(in: .whitespaces)
        if n.isEmpty { return "My Kitchen" }
        return n.hasSuffix("s") ? "\(n)’ Kitchen" : "\(n)’s Kitchen"
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(when)
                .font(.system(size: 11, weight: .semibold)).tracking(3.5)
                .foregroundStyle(Theme.accent)
            Text(owner)
                .font(Theme.serif(32)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            rule
            Text(course)
                .font(.system(size: 10, weight: .semibold)).tracking(3)
                .foregroundStyle(Theme.muted)
            Text(dish.fancyName)
                .font(Theme.serif(22)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(dish.menuDescription)
                .font(Theme.serifUpright(14)).foregroundStyle(Theme.ink.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if let n = dish.nutrition {
                Text("\(n.calories) kcal · \(n.proteinG)g protein")
                    .font(Theme.serif(13)).foregroundStyle(Theme.muted)
            }
            rule
            Text("\(dish.uses.count) leftovers rescued · \(dish.minutes) min fridge to plate")
                .font(.system(size: 10, weight: .semibold)).tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Text("Fridge Chef")
                .font(Theme.serif(12)).foregroundStyle(Theme.accent.opacity(0.8))
                .padding(.top, 2)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 4).stroke(Theme.line, lineWidth: 1).padding(8)
        )
    }

    private var rule: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Theme.ink.opacity(0.25)).frame(width: 48, height: 0.75)
            Circle().fill(Theme.accent).frame(width: 4, height: 4)
            Rectangle().fill(Theme.ink.opacity(0.25)).frame(width: 48, height: 0.75)
        }
        .padding(.vertical, 4)
    }
}

struct TodayLog: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let meals = state.todaysMeals
        if !meals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Today · \(meals.count) meal\(meals.count == 1 ? "" : "s") logged")
                MacroRow(n: state.todaysTotal)
                ForEach(meals) { meal in
                    HStack {
                        Text(meal.name).font(.system(size: 14)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(meal.nutrition.calories) kcal · \(meal.nutrition.proteinG)g P")
                            .font(.system(size: 13)).foregroundStyle(Theme.muted)
                        Button {
                            state.removeMeal(meal)
                        } label: {
                            Image(systemName: "xmark.circle").foregroundStyle(Theme.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(meal.name)")
                    }
                }
                Text("One serving per meal · AI estimates")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.soft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
