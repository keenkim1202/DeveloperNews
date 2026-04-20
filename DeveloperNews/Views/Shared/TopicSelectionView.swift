import SwiftUI

struct TopicSelectionView: View {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(.pickYourDeveloperInterests)
                            .font(.largeTitle.bold())
                        Text(.startWithAFewTopicsWeWillUseThemToShapeYourFirstTrendingFeed)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Text(.selected)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(appState.selectedTopics.count) / \(AppState.maxSelectedTopics)")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(appState.selectedTopics.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                Color(.secondarySystemBackground)
                            }
                            .clipShape(Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Topic.allCases) { topic in
                            let isSelected = appState.selectedTopics.contains(topic)
                            let isDisabled = !isSelected && !appState.canSelectMoreTopics

                            Button(action: { toggleTopic(topic) }) {
                                HStack {
                                    Image(systemName: topic.symbolName)
                                    Text(topic.title)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .padding(.horizontal, 12)
                                .background {
                                    isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground)
                                }
                                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .opacity(isDisabled ? 0.4 : 1)
                            }
                            .buttonStyle(.plain)
                            .disabled(isDisabled)
                        }
                    }

                    Text("Pick 1 to \(AppState.maxSelectedTopics) topics to continue.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("DeveloperNews")
        }
    }

    private func toggleTopic(_ topic: Topic) {
        appState.toggleTopic(topic)
    }
}

