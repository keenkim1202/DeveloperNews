import Foundation
import Observation

// Owns the source-category-preference subsystem: the set of disabled source
// categories, the enabled query, and the toggle operation over it. Pagination
// reset and persistence are delegated back to AppState so the toggle keeps the
// same side effects and writes keep flowing through its serial persistence
// chain. Closures avoid a retain cycle with AppState.
@Observable
@MainActor
final class SourceCategoryStore {
    private let inputs: Inputs

    var disabledSourceCategories: Set<SourceCategory> = []

    // Side effects supplied at init.
    struct Inputs {
        var resetPagination: @MainActor () -> Void
        var persistDisabledSourceCategories: @MainActor (Set<SourceCategory>) -> Void
    }

    init(inputs: Inputs) {
        self.inputs = inputs
    }

    func seedInitialState(disabledSourceCategories: Set<SourceCategory>) {
        self.disabledSourceCategories = disabledSourceCategories
    }

    func isSourceCategoryEnabled(_ category: SourceCategory) -> Bool {
        !disabledSourceCategories.contains(category)
    }

    func setSourceCategory(
        _ category: SourceCategory,
        enabled: Bool,
    ) {
        if enabled {
            disabledSourceCategories.remove(category)
        }
        else {
            disabledSourceCategories.insert(category)
        }
        inputs.resetPagination()
        saveDisabledSourceCategories()
    }

    private func saveDisabledSourceCategories() {
        inputs.persistDisabledSourceCategories(disabledSourceCategories)
    }
}
