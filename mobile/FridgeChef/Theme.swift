import SwiftUI

enum Theme {
    static let ink = Color(red: 0x16 / 255, green: 0x18 / 255, blue: 0x1D / 255)
    static let accent = Color(red: 0xC2 / 255, green: 0x41 / 255, blue: 0x0C / 255)
    static let muted = Color(red: 0x6B / 255, green: 0x70 / 255, blue: 0x7A / 255)
    static let line = Color(red: 0xE5 / 255, green: 0xE7 / 255, blue: 0xEB / 255)
    static let soft = Color(red: 0xFF / 255, green: 0xF7 / 255, blue: 0xED / 255)

    static func serif(_ size: CGFloat) -> Font { .custom("Georgia-Italic", size: size) }
    static func serifUpright(_ size: CGFloat) -> Font { .custom("Georgia", size: size) }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.accent
    init(_ text: String, color: Color = Theme.accent) {
        self.text = text
        self.color = color
    }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(2.2)
            .foregroundStyle(color)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.white.opacity(configuration.isPressed ? 0.6 : 1))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct Chip: View {
    let text: String
    let isOn: Bool
    var body: some View {
        HStack(spacing: 4) {
            if isOn { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
            Text(text)
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(isOn ? .white : Theme.ink)
        .background(isOn ? Theme.ink : .white)
        .overlay(Capsule().stroke(isOn ? Theme.ink : Theme.line, lineWidth: 1))
        .clipShape(Capsule())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct MacroRow: View {
    let n: Nutrition
    var body: some View {
        HStack(spacing: 0) {
            cell("\(n.calories)", "kcal", highlight: true)
            divider
            cell("\(n.proteinG)g", "protein")
            divider
            cell("\(n.carbsG)g", "carbs")
            divider
            cell("\(n.fatG)g", "fat")
        }
        .padding(.vertical, 12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(Theme.line).frame(width: 1, height: 30)
    }

    private func cell(_ value: String, _ label: String, highlight: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(highlight ? Theme.accent : Theme.ink)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold)).tracking(1.5)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
    }
}

extension View {
    func fieldStyle() -> some View { modifier(FieldStyle()) }
}
