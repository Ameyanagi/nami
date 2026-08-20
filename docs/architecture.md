# Architecture

Nami owns Windows, convolution, correlation, resampling, spectral analysis, STFT, peaks, smoothing, and filter algorithms.

## Dependency boundary

The `nami` package and `mojo-nami` distribution use only the Mojo standard
library. The separately compiled future `nami_spectral` package and
`mojo-nami-spectral` distribution may depend on both `mojo-nami` and ShuhaFFT.
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

nami_spectral companion (later, separately installed and imported)
  └── depends on nami + ShuhaFFT adapter
      ├── spectra
      └── STFT
```

`src/nami/` must compile and its elementary test/package lane must pass when
ShuhaFFT is absent. FFT-dependent source lives in the sibling
`src/nami_spectral/` package, which is precompiled into a different artifact
and installed by a different distribution. It may import `nami` and ShuhaFFT;
`nami` must never import `nami_spectral`. Both the absent-companion elementary
lane and the installed-companion spectral lane are required before a spectral
API can merge.

This source-root split is an enforceable Mojo 1.0 boundary. A nested package is
validated when its parent package directory is precompiled, so an unresolved
dependency inside `src/nami/spectral/` would break the supposedly independent
core build even without a root re-export.

The current direct convolution is an I/O- and FFT-independent scalar kernel.
Its `signal` and `kernel` roles control SAME and VALID output shapes; later
optimized kernels must preserve those shape, validation, ownership, and
finite-result semantics.

The pinned primary-source study, domain ownership decisions, proposed module
surface, validation corpus, and dependency-ordered issue sequence live in the
[reference architecture](reference-architecture.md). New signal-processing
domains should reconcile their contract with that document before creating a
module or root export.

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
