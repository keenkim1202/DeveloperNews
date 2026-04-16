import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(Color.black.opacity(0.85))
            }
            .shadow(color: Color.black.opacity(0.25), radius: 8, y: 3)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
    }
}

