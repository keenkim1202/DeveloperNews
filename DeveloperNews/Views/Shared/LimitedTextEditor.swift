import SwiftUI

struct LimitedTextEditor: View {
    private var text: Binding<String>
    private let limit: Int
    private let placeholder: LocalizedStringResource?

    init(
        text: Binding<String>,
        limit: Int,
        placeholder: LocalizedStringResource? = nil,
    ) {
        self.text = text
        self.limit = limit
        self.placeholder = placeholder
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                if let placeholder, text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(8)
            .background {
                DSColor.surface
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            }
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

