import SwiftUI

struct FocusChip: View {
    private let title: LocalizedStringResource
    private let systemImage: String
    private let isSelected: Bool
    private let action: () -> Void

    init(
        title: LocalizedStringResource,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.dsLabel)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                isSelected ? DSColor.accent.opacity(0.2) : DSColor.surface
            }
            .foregroundStyle(isSelected ? DSColor.accent : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

