import SwiftUI

// Instagram-style follow control: filled accent when not following, outlined
// secondary when already following. Reused by the profile header and follow list.
struct FollowButton: View {
    private let isFollowing: Bool
    private let action: () -> Void

    init(
        isFollowing: Bool,
        action: @escaping () -> Void,
    ) {
        self.isFollowing = isFollowing
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(isFollowing ? .communityFollowing : .communityFollow)
                .font(.dsCardTitle)
                .frame(minWidth: 96)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background {
                    if isFollowing {
                        DSColor.surface
                    }
                    else {
                        DSColor.accent
                    }
                }
                .foregroundStyle(isFollowing ? Color.primary : DSColor.onAccent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if isFollowing {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(DSColor.fill, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.borderless)
    }
}
