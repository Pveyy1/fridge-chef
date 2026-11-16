import SwiftUI

struct RecipeView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if let dish = state.chosen {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Step 4 · Cook")
                        Text(dish.fancyName)
                            .font(Theme.serif(28)).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("aka \(dish.plainName) · \(dish.minutes) min · \(dish.difficulty)")
                            .font(.system(size: 14)).foregroundStyle(Theme.muted)
                    }

                    if let n = dish.nutrition {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("Nutrition per serving")
                            MacroRow(n: n)
                            Text("Serves \(dish.servings ?? 2) · \(n.fiberG)g fiber · AI estimate, not exact")
                                .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("You’ll use")
                        Text(dish.uses.joined(separator: " · ") + " · plus staples")
                            .font(.system(size: 15)).foregroundStyle(Theme.ink)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow("Method")
                        ForEach(Array(dish.steps.enumerated()), id: \.offset) { i, step in
                            stepRow(i, step)
                        }
                    }

                    if !dish.platingTip.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow("Plating tip")
                            Text(dish.platingTip)
                                .font(Theme.serif(17)).foregroundStyle(Theme.ink)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.soft)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Theme.accent).frame(width: 3)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(spacing: 10) {
                        Button("I made it!") { state.madeIt() }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Back to the menu") { state.stage = .menu }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(20)
            }
        }
    }

    private func stepRow(_ i: Int, _ step: String) -> some View {
        let done = state.checkedSteps.contains(i)
        return Button {
            if done { state.checkedSteps.remove(i) } else { state.checkedSteps.insert(i) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: done ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(done ? Theme.accent : Theme.muted)
                Text("\(i + 1). \(step)")
                    .font(.system(size: 16))
                    .foregroundStyle(done ? Theme.muted : Theme.ink)
                    .strikethrough(done, color: Theme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
