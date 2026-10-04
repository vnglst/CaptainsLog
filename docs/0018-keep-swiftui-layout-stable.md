# Keep SwiftUI layout stable

**Status**: Accepted

## Decision Outcome

SwiftUI must not shift surrounding layout when views appear or disappear. For conditional elements that would move siblings, keep their space with `.opacity(condition ? 1 : 0)` and `.allowsHitTesting(condition)`; prefer fixed-size containers.
