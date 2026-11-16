import SwiftUI

struct ReviewView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Step 2 · Review")
                    Text(state.detection.sure.isEmpty && state.detection.unsure.isEmpty
                         ? "What’s in the fridge?"
                         : "Here’s what we found.")
                        .font(Theme.serif(30)).foregroundStyle(Theme.ink)
                    Text("Tap to add or remove. The chef will cook with only these (plus salt, pepper, oil, butter and water).")
                        .font(.system(size: 15)).foregroundStyle(Theme.muted)
                }

                if !state.detection.useFirst.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "clock.badge.exclamationmark").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow("Use these first")
                            Text(state.detection.useFirst.joined(separator: ", ").capitalizedFirst)
                                .font(.system(size: 15)).foregroundStyle(Theme.ink)
                            Text("We’ll build tonight’s menu around them.")
                                .font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.soft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if !state.detection.unsure.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow("Not sure about these. Is this…?")
                        ForEach(state.detection.unsure) { item in
                            UnsureQuestion(item: item)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow("Ingredients")
                    FlowLayout(spacing: 8) {
                        ForEach(state.chipOrder, id: \.self) { name in
                            Button {
                                if state.selected.contains(name) { state.selected.remove(name) }
                                else { state.selected.insert(name) }
                            } label: {
                                Chip(text: name, isOn: state.selected.contains(name))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Anything else?")
                    TextField("e.g. half a lemon, leftover chicken", text: $state.extraText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .fieldStyle()
                }

                WhatToMake()

                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Dietary notes (optional)")
                    TextField("e.g. vegetarian, no nuts, low spice", text: $state.dietaryNotes, axis: .vertical)
                        .fieldStyle()
                }

                VStack(spacing: 10) {
                    Button("Plan tonight’s menu") { Task { await state.planMenu() } }
                        .buttonStyle(PrimaryButtonStyle())
                    Text("\(state.finalIngredients.count) ingredients selected")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                    Button("Back to photos") { state.stage = .snap }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct UnsureQuestion: View {
    @Environment(AppState.self) private var state
    let item: UnsureItem

    var body: some View {
        @Bindable var state = state
        let choice = state.unsureChoice[item.looksLike]
        VStack(alignment: .leading, spacing: 10) {
            Text("Looks like: \(item.looksLike)")
                .font(Theme.serif(17)).foregroundStyle(Theme.ink)
            FlowLayout(spacing: 8) {
                ForEach(item.options, id: \.self) { opt in
                    radio(opt, value: opt, choice: choice)
                }
                radio("Something else", value: AppState.other, choice: choice)
                radio("Skip it", value: AppState.skip, choice: choice)
            }
            if choice == AppState.other {
                TextField("What is it?", text: Binding(
                    get: { state.unsureOther[item.looksLike] ?? "" },
                    set: { state.unsureOther[item.looksLike] = $0 }))
                    .textInputAutocapitalization(.never)
                    .fieldStyle()
            }
        }
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }

    private func radio(_ label: String, value: String, choice: String?) -> some View {
        Button {
            state.unsureChoice[item.looksLike] = value
        } label: {
            HStack(spacing: 6) {
                Image(systemName: choice == value ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(choice == value ? Theme.accent : Theme.muted)
                Text(label).foregroundStyle(Theme.ink)
            }
            .font(.system(size: 14))
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(choice == value ? Theme.soft : .white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

private struct WhatToMake: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("What are we making?")
                Text("Optional. Leave it on “Surprise me” and the chef decides.")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
            }

            VStack(alignment: .leading, spacing: 8) {
                label("Meal")
                FlowLayout(spacing: 8) {
                    chip("Surprise me", on: state.mealType.isEmpty) { state.mealType = "" }
                    ForEach(AppState.mealTypes, id: \.self) { m in
                        chip(m, on: state.mealType == m) { state.mealType = m }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                label("Flavor (pick any)")
                FlowLayout(spacing: 8) {
                    chip("Surprise me", on: state.flavors.isEmpty) { state.flavors = [] }
                    ForEach(AppState.flavorOptions, id: \.self) { f in
                        chip(f, on: state.flavors.contains(f)) {
                            if state.flavors.contains(f) { state.flavors.remove(f) } else { state.flavors.insert(f) }
                        }
                    }
                }
            }

            HStack {
                label("Cooking for")
                Spacer()
                Stepper(value: $state.people, in: 1...12) {
                    Text("\(state.people) \(state.people == 1 ? "person" : "people")")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: 8) {
                label("Note to the chef")
                TextField("e.g. date night, quick before the gym, kid-friendly", text: $state.guidance, axis: .vertical)
                    .fieldStyle()
            }
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
    }

    private func chip(_ text: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(on ? .white : Theme.ink)
                .background(on ? Theme.accent : .white)
                .overlay(Capsule().stroke(on ? Theme.accent : Theme.line, lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
