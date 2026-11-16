import SwiftUI

struct MenuView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Step 3 · Your menu")
                    Text("Three ways to \(state.mealWord).")
                        .font(Theme.serif(30)).foregroundStyle(Theme.ink)
                    Text("Everything here comes from your fridge — nothing to buy.")
                        .font(.system(size: 15)).foregroundStyle(Theme.muted)
                }

                ForEach(Array(state.dishes.enumerated()), id: \.element.id) { index, dish in
                    DishCard(number: index + 1, dish: dish) { state.cook(dish) }
                }

                HStack(spacing: 10) {
                    Button("Edit ingredients") { state.stage = .review }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Start over") { state.startOver() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(20)
        }
    }
}

private struct DishCard: View {
    let number: Int
    let dish: Dish
    let onCook: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("No. \(number)", color: Theme.muted)
            Text(dish.fancyName)
                .font(Theme.serif(22))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("aka \(dish.plainName)")
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
            Text(dish.menuDescription)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Text("\(dish.minutes) min · \(dish.difficulty) · \(dish.uses.count) ingredients used")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            if let n = dish.nutrition {
                Text("≈ \(n.calories) kcal · \(n.proteinG)g protein · \(n.carbsG)g carbs · \(n.fatG)g fat")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink)
            }
            Text(dish.uses.joined(separator: ", "))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            Button("Cook this", action: onCook)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
        }
        .padding(18)
        .background(.white)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
