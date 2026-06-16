import SwiftUI

/// Lays out subviews left-to-right, wrapping to a new line when the current
/// row runs out of width. Used for tag/chip pickers where item widths vary.
struct FlowLayout: Layout {
    private let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void,
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, maxWidth: maxWidth)
        let height = rows.reduce(into: CGFloat.zero) { total, row in
            total += row.height
        }
        let spacingHeight = spacing * CGFloat(max(0, rows.count - 1))
        // When the proposed width is unbounded, fall back to the widest row's
        // content width instead of returning an infinite size.
        let contentWidth = rows.map(\.width).max() ?? 0
        let width = maxWidth.isFinite ? maxWidth : contentWidth
        return CGSize(width: width, height: height + spacingHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void,
    ) {
        let rows = arrange(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(
        subviews: Subviews,
        maxWidth: CGFloat,
    ) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x = CGFloat.zero

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.indices.isEmpty, x + size.width > maxWidth {
                current.width = x - spacing
                rows.append(current)
                current = Row()
                x = 0
            }
            current.indices.append(index)
            current.height = max(current.height, size.height)
            x += size.width + spacing
        }

        if !current.indices.isEmpty {
            current.width = x - spacing
            rows.append(current)
        }
        return rows
    }

    private struct Row {
        var indices: [Int] = []
        var height: CGFloat = 0
        var width: CGFloat = 0
    }
}
