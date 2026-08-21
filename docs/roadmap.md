# Roadmap

This roadmap is an execution contract. A milestone is complete only when its
API, numerical semantics, reference tests, invariant tests, example, and
compatibility notes land together.

## v0.1 — Foundation

### Stage 1 — Dependency-free windows

- [x] Add nominal symmetric/periodic sampling modes.
- [x] Add nominal formula/peak normalization modes.
- [x] Implement `Float64` Hann, Hamming, and three-term Blackman windows.
- [x] Specify zero, singleton, invalid-length, and degenerate-peak behavior.
- [x] Cover analytic reference values, symmetry, periodic extension, and peak
  normalization properties.
- [x] Export only the implemented API and provide a compiling example.

Acceptance gate: `pixi run check` passes without ShuhaFFT in the environment,
and the installed-package smoke test calls a public window function.

### Stage 2 — Dependency-free direct operations

- [x] Define nominal `FULL`, `SAME`, and `VALID` output modes, including which
  input controls `SAME` length.
- [x] Specify empty-input and size-overflow error behavior before implementation.
- [x] Implement correctness-first direct `Float64` convolution.
- [x] Implement correlation with an explicit lag convention.
- [x] Add hand-computed fixtures and invariants for commutativity, impulses,
  constants, and convolution/correlation relationships.
- [x] Add a small example and size-based benchmark methodology.

Acceptance gate: elementary tests and package precompilation remain green with
no ShuhaFFT import in the root, windows, convolution, or correlation modules.

### Stage 3 — Stable elementary surface

- [ ] Exercise windows and direct operations in one independent consumer.
- [ ] Decide, from measured call sites, whether borrowed-buffer overloads are
  needed; do not introduce a Nami-specific array.
- [ ] Document tolerances and allocation behavior for every public operation.
- [ ] Freeze the dependency-free root exports for the v0.1 release candidate.

Acceptance gate: the root API has no placeholders and every public symbol has a
compiled example or downstream use.

### Stage 4 — Isolated spectral API

This stage begins only after ShuhaFFT has a compatible tagged release and its
planner/normalization contract is documented.

- [x] Add ShuhaFFT only to a `nami.spectral` adapter layer.
- [x] Define frequency-bin ordering, transform normalization, real-input output
  length, sample-rate validation, and units before implementation.
- [ ] Add a separate spectral CI lane with ShuhaFFT installed.
- [ ] Keep an elementary CI lane in which ShuhaFFT is absent.
- [x] Implement the smallest useful real-signal spectrum operation.
- [x] Add sinusoid/bin reference fixtures and energy invariants.
- [ ] Decide and document how the distribution expresses the spectral optional
  dependency; do not ship a silently broken submodule.

Acceptance gate: removing ShuhaFFT still permits importing `nami` and compiling
every Stage 1–3 example and test. Importing `nami.spectral` is the only action
that may require ShuhaFFT.

## v0.2 — Usability

- Add resampling, smoothing, and peak finding one contract at a time.
- Add borrowed-buffer or generic numeric APIs only after downstream evidence.
- Expand integration fixtures and publish the modular-community recipe once the
  package is useful on its own.

## v0.3 — Performance

- Add representative datasets, reproducible baselines, and allocation metrics.
- Optimize measured bottlenecks without changing mathematical semantics.
- Add SIMD-specialized kernels behind the same public contracts.

## v1.0 — Stability

- Document every public symbol, allocation rule, tolerance, and error contract.
- Publish a compatibility and deprecation policy.
- Support the declared operating-system and architecture matrix in CI.
- Require production evidence from at least one independent consumer.

## Not planned

Audio devices, codecs, media pipelines, plotting, interpolation, optimization,
and a second FFT implementation are outside this package.
