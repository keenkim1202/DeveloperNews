import SwiftUI

struct LimitedTextField: View {
    private var text: Binding<String>
    private let limit: Int
    private let prompt: LocalizedStringResource

    init(
        text: Binding<String>,
        limit: Int,
        prompt: LocalizedStringResource,
    ) {
        self.text = text
        self.limit = limit
        self.prompt = prompt
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextField(prompt, text: text)
                .keenOnChange(of: text.wrappedValue, perform: onTextChange)
            Text("\(text.wrappedValue.count) / \(limit)")
                .font(.caption2)
                .foregroundStyle(text.wrappedValue.count >= limit ? DSColor.destructive : Color.secondary)
        }
    }

    private func onTextChange(_ new: String) {
        if new.count > limit {
            text.wrappedValue = String(new.prefix(limit))
        }
    }
}

