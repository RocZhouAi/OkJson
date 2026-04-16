//  ElasticSplitView.swift
//  OkJson
//
//  NSSplitView subclass that properly handles equal column widths
//  without Auto Layout overriding our settings

import AppKit

/// A SplitView that supports equal-width columns and proper layout control
class ElasticSplitView: NSSplitView {

    // MARK: - Properties

    /// Whether columns should be forced to equal widths
    var shouldEqualizeColumns: Bool = true

    /// Flag to prevent equalization during user-initiated divider drags
    private var isUserDraggingDivider: Bool = false

    /// Track whether we're in an animation (don't equalize during animations)
    private var isInAnimation: Bool = false

    // MARK: - Overrides

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)

        // Equalize after layout completes, but:
        // 1. Not during user drag
        // 2. Not during animations
        // 3. Only when explicitly requested
        if shouldEqualizeColumns && !isUserDraggingDivider && !isInAnimation {
            // Use a zero-delay call to ensure we're in the next runloop pass
            // AFTER all Auto Layout constraints have been applied
            DispatchQueue.main.async { [weak self] in
                self?.equalizeColumnWidths()
            }
        }
    }

    // MARK: - Public Methods

    /// Force all columns to equal width
    func equalizeColumnWidths() {
        let arrangedCount = arrangedSubviews.count
        guard arrangedCount > 1 else { return }

        // Use the visible width of the splitview
        let totalWidth = bounds.width
        guard totalWidth > 0 else { return }

        let count = CGFloat(arrangedCount)
        let dividerCount = CGFloat(arrangedCount - 1)
        let dividerWidth = dividerThickness
        let columnWidth = (totalWidth - dividerWidth * dividerCount) / count

        // Calculate divider positions
        for i in 0..<arrangedCount - 1 {
            let position = columnWidth * CGFloat(i + 1) + dividerWidth * CGFloat(i)
            setPosition(position, ofDividerAt: i)
        }
    }

    /// Calculate the position of a divider for equal-width columns
    /// Can be used for animation
    func positionForDivider(at index: Int, totalWidth: CGFloat) -> CGFloat {
        let arrangedCount = arrangedSubviews.count
        let count = CGFloat(arrangedCount)
        let dividerCount = CGFloat(arrangedCount - 1)
        let dividerWidth = dividerThickness
        let columnWidth = (totalWidth - dividerWidth * dividerCount) / count
        return columnWidth * CGFloat(index + 1) + dividerWidth * CGFloat(index)
    }

    // MARK: - Mouse Tracking

    override func mouseDown(with event: NSEvent) {
        let locationInWindow = event.locationInWindow
        let localPoint = convert(locationInWindow, from: nil)

        // Check if clicking on a divider
        var isOnDivider = false
        let arrangedCount = arrangedSubviews.count
        for i in 0..<arrangedCount - 1 {
            // Calculate divider position manually
            let dividerPosition = arrangedSubviews[i].frame.maxX
            let dividerThickness = self.dividerThickness
            let dividerRect = NSRect(x: dividerPosition, y: 0, width: dividerThickness, height: bounds.height)
            if dividerRect.contains(localPoint) {
                isOnDivider = true
                break
            }
        }

        isUserDraggingDivider = isOnDivider
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        isUserDraggingDivider = false

        // Equalize after user finishes dragging
        if shouldEqualizeColumns {
            DispatchQueue.main.async { [weak self] in
                self?.equalizeColumnWidths()
            }
        }
    }
}
