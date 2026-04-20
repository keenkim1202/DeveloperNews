import SwiftUI

struct SplashView: View {
    private let appState: AppState
    private let onComplete: () -> Void

    init(
        appState: AppState,
        onComplete: @escaping () -> Void,
    ) {
        self.appState = appState
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 20) {
            Image("LaunchIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)

            Text("DeveloperNews")
                .font(.keenPixelTitle)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color(.systemBackground).ignoresSafeArea()
        }
        .onAppear(perform: onAppear)
    }

    private func onAppear() {
        Task {
            await appState.loadIfNeeded()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onComplete()
        }
    }
}

