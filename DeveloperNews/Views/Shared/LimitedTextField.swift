import SwiftUI

struct LimitedTextField: View {
    var text: Binding<String>
    let limit: Int
    let prompt: LocalizedStringResource

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextField(prompt, text: text)
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

