import SwiftUI

struct ToastView: View {
    private let message: String

    init(message: String) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .font(.footnote.weight(.medium))
            .foregroundStyle(DSColor.onAccent)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(DSColor.scrim.opacity(0.85))
            }
            .shadow(color: DSColor.scrim.opacity(0.25), radius: 8, y: 3)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
    }
}

