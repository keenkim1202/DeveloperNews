import XCTest
@testable import DeveloperNews

// Constructs SourceCategoryStore directly with no-op side-effect closures and
// exercises the enable/disable toggle and the enabled query. Test methods are
// async so they run on the main-actor executor (the app target compiles with
// MainActor default isolation, and constructing the @Observable store off that
// executor traps).
@MainActor
final class SourceCategoryStoreTests: XCTestCase {
    private func makeStore(onResetPagination: @escaping @MainActor () -> Void = {}) -> SourceCategoryStore {
        SourceCategoryStore(
            inputs: SourceCategoryStore.Inputs(
                resetPagination: onResetPagination,
                persistDisabledSourceCategories: { _ in }))
    }

    func testCategoriesEnabledByDefault() async {
        let store = makeStore()

        for category in SourceCategory.allCases {
            XCTAssertTrue(store.isSourceCategoryEnabled(category))
        }
    }

    func testDisableThenEnableTogglesMembership() async {
        let store = makeStore()

        store.setSourceCategory(.reddit, enabled: false)
        XCTAssertFalse(store.isSourceCategoryEnabled(.reddit))
        XCTAssertTrue(store.disabledSourceCategories.contains(.reddit))

        store.setSourceCategory(.reddit, enabled: true)
        XCTAssertTrue(store.isSourceCategoryEnabled(.reddit))
        XCTAssertFalse(store.disabledSourceCategories.contains(.reddit))
    }

    func testTogglingInvokesResetPagination() async {
        var resetCount = 0
        let store = makeStore(onResetPagination: { resetCount += 1 })

        store.setSourceCategory(.github, enabled: false)
        store.setSourceCategory(.github, enabled: true)

        XCTAssertEqual(resetCount, 2)
    }

    func testDisablingOneCategoryLeavesOthersEnabled() async {
        let store = makeStore()

        store.setSourceCategory(.hackerNews, enabled: false)

        XCTAssertFalse(store.isSourceCategoryEnabled(.hackerNews))
        XCTAssertTrue(store.isSourceCategoryEnabled(.article))
        XCTAssertTrue(store.isSourceCategoryEnabled(.github))
    }
}
