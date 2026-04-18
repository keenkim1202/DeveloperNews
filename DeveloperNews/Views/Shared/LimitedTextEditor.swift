import SwiftUI

struct LimitedTextEditor: View {
    var text: Binding<String>
    let limit: Int

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
        if new.count > limit { text.wrappedValue = String(new.prefix(limit)) }
    }
}

