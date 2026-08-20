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

nami.spectral (later, explicitly imported)
  └── ShuhaFFT adapter
      ├── spectra
      └── STFT
```

The root package must compile and its elementary test lane must pass when
ShuhaFFT is absent. A spectral module may import ShuhaFFT, but the root and all
elementary modules must never import the spectral layer. This one-way boundary
is tested before a spectral API can merge.

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
