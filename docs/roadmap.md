# Roadmap

This roadmap separates the shipped v0.1 surface from future work. A milestone
is complete only when its API, numerical semantics, reference tests, invariant
tests, example, and compatibility notes land together.

## v0.1 — Foundation

- [x] Ship general-cosine and six named windows with explicit sampling and
  normalization modes.
- [x] Ship direct convolution and correlation with SIMD chunking and scalar
  differential coverage.
- [x] Ship constant/linear detrending and Savitzky–Golay smoothing.
- [x] Ship complete peak metadata and caller-owned reusable workspace APIs.
- [x] Isolate one-sided periodogram, Welch, and spectrogram operations under
  `nami.spectral`, backed by exactly pinned ShuhaFFT 0.1.0.
- [x] Compile every example and README snippet and exercise the full public
  surface from the installed package.
- [x] Build and test packages on macOS ARM64, Linux x86-64, and Linux ARM64.

## v0.2 — Usability

- Add resampling and filter-design operations one contract at a time.
- Add borrowed-buffer or generic numeric APIs only after downstream evidence.
- Expand streaming and multichannel workflows without changing v0.1 numerical
  conventions silently.

## v0.3 — Performance

- Expand representative datasets, reproducible baselines, and allocation
  metrics.
- Continue optimizing measured bottlenecks without changing mathematical
  semantics.
- Extend SIMD-specialized kernels behind the same public contracts.

## v1.0 — Stability

- Document every public symbol, allocation rule, tolerance, and error contract.
- Publish a compatibility and deprecation policy.
- Support the declared operating-system and architecture matrix in CI.
- Require production evidence from at least one independent consumer.

## Not planned

Audio devices, codecs, media pipelines, plotting, interpolation, optimization,
and a second FFT implementation are outside this package.
