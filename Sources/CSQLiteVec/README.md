# sqlite-vec vendored source

This target contains the official `sqlite-vec` v0.1.10-alpha.4 amalgamation from:

https://github.com/asg017/sqlite-vec/releases/tag/v0.1.10-alpha.4

This is the newest published upstream version, marked as a prerelease.
The downloaded `sqlite-vec-0.1.10-alpha.4-amalgamation.tar.gz` archive SHA-256 is
`49a122dc366181685528257d02a5e05117292c8e228b72de57718d8dade99b7c`.
It is compiled statically with SQLite and NEON enabled for the Apple Silicon-only app.

Upstream is dual-licensed under MIT or Apache-2.0; both license texts are included.

The upstream archive omits its included DiskANN, IVF and rescore split sources.
The four matching `sqlite-vec-*.c` files are copied verbatim from release commit
`04d28bd21773981e2d266bbf6aa4efbd011eb4f6`; the amalgamation and header remain unchanged.
