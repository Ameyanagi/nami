# Architecture

Nami owns Windows, convolution, correlation, resampling, spectral analysis, STFT, peaks, smoothing, and filter algorithms.

## Dependency boundary

Allowed ecosystem dependencies: ShuhaFFT only for algorithms that require transforms; elementary operations remain independently usable.
Expected downstream consumers: Scientific analysis programs and domain-specific signal-processing packages.

Dependencies point from applications and higher-level packages toward smaller
foundations. This repository must never import a downstream consumer. New
dependencies require a documented need and must not force unrelated users to
install an application, renderer, language layer, or scientific stack.

## Layers

```text
nami root
  └── dependency-free public exports
      ├── windows
      ├── direct convolution/correlation
      └── later smoothing, peaks, and direct resampling

nami.spectral (explicitly imported)
  └── ShuhaFFT adapter
      ├── spectra
      └── STFT
```

The root package must compile and its elementary test lane must pass when
ShuhaFFT is absent. A spectral module may import ShuhaFFT, but the root and all
elementary modules must never import the spectral layer. This one-way boundary
is tested before a spectral API can merge.

The direct convolution is an I/O- and FFT-independent native-SIMD kernel with a
scalar tail and a private scalar differential reference. Its `signal` and
`kernel` roles control SAME and VALID output shapes. SIMD pointer access is
limited to validated, rounded-down contiguous chunks and is covered by tail,
mode, and overflow differential tests.

Peak analysis builds reusable nearest-greater and range-minimum indexes. The
owning `find_peaks` wrapper is the simple path; `find_peaks_into` accepts a
caller-owned `Peaks` result and `PeakWorkspace` for repeated batch work. One
workspace is used by only one worker at a time.

The package root exports only the small documented public surface. Algorithms,
generated tables, platform details, and backend implementations remain in
their owning modules. Generic Mojo-native buffers, spans, strings, and
collections are preferred over an ecosystem-specific universal container.

## Data flow

Input validation occurs at the public boundary. Internal layers operate on
explicit typed values, produce deterministic outputs for deterministic inputs,
and report invalid state rather than silently replacing it with a default.
I/O, clocks, randomness, terminal queries, filesystem access, and accelerator
selection stay at explicit effect or backend boundaries.
