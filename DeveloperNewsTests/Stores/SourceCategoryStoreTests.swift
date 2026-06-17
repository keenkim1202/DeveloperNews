import Testing
import Foundation
@testable import DeveloperNews

// Constructs SourceCategoryStore directly with no-op side-effect closures and
// exercises the enable/disable toggle and the enabled query. Test methods are
// async so they run on the main-actor executor (the app target compiles with
// MainActor default isolation, and constructing the @Observable store off that
// executor traps).
@MainActor
@Suite struct SourceCategoryStoreTests {
    private func makeStore(onResetPagination: @escaping @MainActor () -> Void = {}) -> SourceCategoryStore {
        SourceCategoryStore(
            inputs: SourceCategoryStore.Inputs(
                resetPagination: onResetPagination,
                persistDisabledSourceCategories: { _ in }))
    }

    @Test func categoriesEnabledByDefault() async {
        let store = makeStore()

        for category in SourceCategory.allCases {
            #expect(store.isSourceCategoryEnabled(category))
        }
    }

    @Test func disableThenEnableTogglesMembership() async {
        let store = makeStore()

        store.setSourceCategory(.reddit, enabled: false)
        #expect(!store.isSourceCategoryEnabled(.reddit))
        #expect(store.disabledSourceCategories.contains(.reddit))

        store.setSourceCategory(.reddit, enabled: true)
        #expect(store.isSourceCategoryEnabled(.reddit))
        #expect(!store.disabledSourceCategories.contains(.reddit))
    }

    @Test func togglingInvokesResetPagination() async {
        var resetCount = 0
        let store = makeStore(onResetPagination: { resetCount += 1 })

        store.setSourceCategory(.github, enabled: false)
        store.setSourceCategory(.github, enabled: true)

        #expect(resetCount == 2)
    }

    @Test func disablingOneCategoryLeavesOthersEnabled() async {
        let store = makeStore()

        store.setSourceCategory(.hackerNews, enabled: false)

        #expect(!store.isSourceCategoryEnabled(.hackerNews))
        #expect(store.isSourceCategoryEnabled(.article))
        #expect(store.isSourceCategoryEnabled(.github))
    }
}
