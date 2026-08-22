# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and uses semantic versioning after the first public release.

## [Unreleased]

### Added

- Initial experimental repository scaffold.
- Dependency-free arbitrary-term general-cosine windows plus Hann, Hamming, and
  Blackman wrappers, with explicit symmetric or periodic sampling and formula
  or peak normalization.
- Dependency-free direct `Float64` convolution with explicit FULL, SAME, and
  VALID shape, finite-data, overflow, and ownership semantics.
- Complete peak heights, prominence bases, widths, width heights, and
  interpolated intersections, plus allocation-reusing `find_peaks_into` and
  `PeakWorkspace` APIs.
- A compiled p50/p95 analysis benchmark and reusable peak-analysis example.

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
