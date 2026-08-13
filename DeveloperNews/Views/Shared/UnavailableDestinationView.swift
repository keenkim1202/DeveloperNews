import SwiftUI

struct UnavailableDestinationView: View {
    enum Reason {
        case itemNotFound
        case postDeleted
        case profileUnavailable
        // The read failed. Distinct from the cases above, which mean the record
        // is genuinely gone — telling someone their post was deleted because
        // the network dropped is a worse answer than saying nothing.
        case loadFailed
    }

    private let reason: Reason
    private let onRetry: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    init(
        reason: Reason,
        onRetry: (() -> Void)? = nil,
    ) {
        self.reason = reason
        self.onRetry = onRetry
    }

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(headline)
            } icon: {
                Image(symbol)
            }
        } description: {
            Text(message)
        } actions: {
            if let onRetry {
                Button(action: onRetry) {
                    Text(.unavailableDestinationTryAgain)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                Button(action: goBack) {
                    Text(.unavailableDestinationGoBack)
                }
                .buttonStyle(.bordered)
            }
            else {
                Button(action: goBack) {
                    Text(.unavailableDestinationGoBack)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var headline: LocalizedStringResource {
        switch reason {
        case .itemNotFound:       .unavailableDestinationContentHeadline
        case .postDeleted:        .unavailableDestinationPostHeadline
        case .profileUnavailable: .unavailableDestinationProfileHeadline
        case .loadFailed:         .unavailableDestinationLoadFailedHeadline
        }
    }

    private var symbol: DSIcon {
        switch reason {
        case .itemNotFound:       .emptyTray
        case .postDeleted:        .delete
        case .profileUnavailable: .blockedUsers
        case .loadFailed:         .refresh
        }
    }

    private var message: LocalizedStringResource {
        switch reason {
        case .itemNotFound:       .unavailableDestinationContentMessage
        case .postDeleted:        .unavailableDestinationPostMessage
        case .profileUnavailable: .unavailableDestinationProfileMessage
        case .loadFailed:         .unavailableDestinationLoadFailedMessage
        }
    }

    private func goBack() {
        dismiss()
    }
}
