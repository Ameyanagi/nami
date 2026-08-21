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

### Changed

- Replaced mode factories and boolean-backed mode storage with Int-backed
  `ConvolutionMode`, `WindowSampling`, and `WindowNormalization` constants.
- Replaced the hardcoded two-pi literal and finite-value helper with Mojo 1.0
  standard-library math APIs.
