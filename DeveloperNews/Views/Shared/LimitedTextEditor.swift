import SwiftUI

struct LimitedTextEditor: View {
    private var text: Binding<String>
    private let limit: Int

    init(
        text: Binding<String>,
        limit: Int,
    ) {
        self.text = text
        self.limit = limit
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextEditor(text: text)
                .frame(minHeight: 100)
                .keenOnChange(of: text.wrappedValue, perform: onTextChange)
            Text("\(text.wrappedValue.count) / \(limit)")
                .font(.caption2)
                .foregroundStyle(text.wrappedValue.count >= limit ? Color.red : Color.secondary)
        }
    }

    private func onTextChange(_ new: String) {
        if new.count > limit {
            text.wrappedValue = String(new.prefix(limit))
        }
    }
}

