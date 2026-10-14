# Vendored Swift packages

These complete upstream source trees preserve resources, examples, tests and
licenses. Only the dependency constraints in the four package manifests differ
from upstream; `dependency-constraints.patch` records those exact changes.

| Package | Release | Source revision |
| --- | --- | --- |
| [swift-transformers](https://github.com/huggingface/swift-transformers/tree/1.3.5) | 1.3.5 | `48473106a93b2d8dfb114b82f0628ebbb71734e7` |
| [swift-huggingface](https://github.com/huggingface/swift-huggingface/tree/1.0.0) | 1.0.0 | `c30143a4616f3fa994ee3ab3e3464f752845c07c` |

Both upstream packages constrain Swift Crypto below 5.0.0, and Transformers pins
yyjson 0.12.0. The local manifests allow Crypto below 6.0.0 and pin yyjson 0.13.0.
Root `Package.resolved` records the selected remote transitive versions. The local
packages retain their upstream identities and public products.

To refresh, check out each immutable upstream revision, copy every tracked file
without its `.git` directory, and apply or update the constraint-only patch.
Compare every copied file with that revision: only `Package.swift` and its
Swift-version manifest should differ in each package. Verify build, tests,
packaging notices and sequential fixture evaluations before committing changes.
The packaging helper includes licenses and notices from these trees alongside
remote SwiftPM checkout notices.
