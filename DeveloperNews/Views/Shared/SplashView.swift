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
            Image(.launchIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: DSColor.scrim.opacity(0.18), radius: 16, y: 8)

            Text("DeveloperNews")
                .font(.keenPixelTitle)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            DSColor.background.ignoresSafeArea()
        }
        .task(loadContent)
        .task(runSplash)
    }

    @Sendable
    private func loadContent() async {
        await appState.loadIfNeeded()
    }

    @Sendable
    private func runSplash() async {
        try? await Task.sleep(for: .seconds(1.5))
        guard !Task.isCancelled else { return }
        onComplete()
    }
}

