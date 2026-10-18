# Diagnostic overlay follow-ups (see docs/product/diagnostic-overlay.md)

- Build the overlay as specified: engine records and parser split first (§8), then the app model, decoration and gutter (§9), then the self-test (§10).
- C and C++: clang `note:` lines carry locations. Parse them into secondary labels without label text, so clang diagnostics get gutter numbers and underlines.
- rust-analyzer diagnostics stay off. Revisit if the oracle enables `publishDiagnostics`; its `relatedInformation` maps onto secondary labels.
- Ordering by meaning (declared, borrowed, dropped, used) needs rules per error code kept outside rustc's label text. Source order until a user asks.
- A project-wide list of overlays, beside the Problems panel, is not planned.
