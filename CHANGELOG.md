# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Fixed-size `SpectralWorkspace` for allocation-free repeated periodogram and
  Welch analysis into caller-owned lists, with reusable frequency output.
- Independent DFT workspace regression tests, a complete buffer-reuse example,
  and separate construction/steady-state performance measurements.

### Fixed

- Constant and linear detrending now use scaled compensated arithmetic to avoid
  overflowing means and fits for finite near-maximum signals.
- Spectral frequencies, frame centering, densities, and Welch accumulation now
  retain representable extreme and subnormal results without intermediate
  overflow. Unrepresentable residuals, densities, or frame times raise errors.

## [0.1.0] - 2026-08-22

### Added

- Initial experimental repository scaffold.
- Arbitrary-term general-cosine windows plus Hann, Hamming, Blackman, Nuttall,
  Blackman-Harris, and flat-top wrappers, with explicit sampling and
  normalization conventions.
- Direct `Float64` convolution and correlation with explicit FULL, SAME, and
  VALID shapes, finite-data, overflow, and ownership contracts.
- Constant and linear detrending plus Savitzky–Golay coefficient generation and
  smoothing with interpolated edge handling.
- Complete peak heights, prominence bases, widths, width heights, and
  interpolated intersections, plus allocation-reusing `find_peaks_into` and
  `PeakWorkspace` APIs.
- One-sided periodogram, Welch power spectral density, and contiguous
  frame-major spectrogram APIs backed by ShuhaFFT 0.1.0 reusable real plans.
- Compiled examples for elementary filtering, reusable peak analysis, Welch
  workflows, and spectrograms, plus a p50/p95 analysis benchmark.

### Changed

- Replaced mode factories and boolean-backed mode storage with Int-backed
  `ConvolutionMode`, `WindowSampling`, and `WindowNormalization` constants.
- Replaced the hardcoded two-pi literal and finite-value helper with Mojo 1.0
  standard-library math APIs.
- Replaced quadratic peak distance selection and repeated prominence scans with
  heap priority, neighborhood pruning, and reusable nearest-greater/range-
  minimum indexes.
- Vectorized direct convolution across complete native-width kernel chunks,
  retaining scalar tails, per-result finite checks, and a differential scalar
  reference.
- Validate every public nominal-mode argument before dispatch and format
  corrupted values as `INVALID(_value=...)` instead of a valid constant name.

[Unreleased]: https://github.com/Ameyanagi/nami/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Ameyanagi/nami/releases/tag/v0.1.0
