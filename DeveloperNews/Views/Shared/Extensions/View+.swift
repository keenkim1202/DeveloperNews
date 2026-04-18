import SwiftUI

extension View {
    func keenOnChange<V: Equatable>(
        of value: V,
        perform action: @escaping () -> Void
    ) -> some View {
        onChange(of: value) { action() }
    }

    func keenOnChange<V: Equatable>(
        of value: V,
        perform action: @escaping (V) -> Void
    ) -> some View {
        onChange(of: value) { _, new in action(new) }
    }

    func keenOnChange<V: Equatable>(
        of value: V,
        perform action: @escaping (V, V) -> Void
    ) -> some View {
        onChange(of: value) { old, new in action(old, new) }
    }

    func dialog(
        _ title: LocalizedStringResource,
        message: LocalizedStringResource? = nil,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> some View
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: isPresented,
            titleVisibility: .visible,
            actions: actions) {
            if let message {
                Text(message)
            }
        }
    }
}
