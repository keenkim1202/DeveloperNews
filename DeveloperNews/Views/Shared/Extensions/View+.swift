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
}
