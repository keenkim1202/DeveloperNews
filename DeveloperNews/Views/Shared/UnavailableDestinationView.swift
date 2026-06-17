import SwiftUI

struct UnavailableDestinationView: View {
    enum Reason {
        case itemNotFound
        case postDeleted
        case profileUnavailable
    }

    private let reason: Reason
    @Environment(\.dismiss) private var dismiss

    init(reason: Reason) {
        self.reason = reason
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
            Button(action: goBack) {
                Text(.unavailableDestinationGoBack)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var headline: LocalizedStringResource {
        switch reason {
        case .itemNotFound:       .unavailableDestinationContentHeadline
        case .postDeleted:        .unavailableDestinationPostHeadline
        case .profileUnavailable: .unavailableDestinationProfileHeadline
        }
    }

    private var symbol: DSIcon {
        switch reason {
        case .itemNotFound:       .emptyTray
        case .postDeleted:        .delete
        case .profileUnavailable: .blockedUsers
        }
    }

    private var message: LocalizedStringResource {
        switch reason {
        case .itemNotFound:       .unavailableDestinationContentMessage
        case .postDeleted:        .unavailableDestinationPostMessage
        case .profileUnavailable: .unavailableDestinationProfileMessage
        }
    }

    private func goBack() {
        dismiss()
    }
}
