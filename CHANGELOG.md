# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and uses semantic versioning after the first public release.

## [Unreleased]

### Added

- Initial experimental repository scaffold.
- Dependency-free Hann, Hamming, and Blackman windows with explicit symmetric
  or periodic sampling and formula or peak normalization.
- Dependency-free direct `Float64` convolution with explicit FULL, SAME, and
  VALID shape, finite-data, overflow, and ownership semantics.

### Changed

- Made every reachable `ConvolutionMode` storage state denote exactly one of
  FULL, SAME, or VALID.
