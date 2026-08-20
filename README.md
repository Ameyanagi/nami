# Nami

> **Experimental — API not yet released.**

Scientific signal processing for Mojo.

## Scope

Nami provides scientific signal-processing algorithms and delegates Fourier transforms to ShuhaFFT instead of embedding an FFT implementation.

The v0.1 work is deliberately staged: dependency-free windows first, direct
convolution and correlation second, and stabilization of that elementary API
third. After v0.1, a small spectral companion begins only after a compatible
ShuhaFFT release. It is built as the separate `nami_spectral` Mojo package and
`mojo-nami-spectral` distribution, so FFT-dependent source never enters the
dependency-free `nami` artifact. The project is independently installable and
does not require any application from the wider ecosystem.

## Development

Install [Pixi](https://pixi.sh/), then run:

```sh
pixi install --locked
pixi run check
pixi run example
```

The exact stable Mojo compiler and all development dependencies are captured in
`pixi.lock`. Runtime and library code is Mojo-first and pure Mojo wherever
practical. Build-time data generation may use another language when justified,
but generated outputs must be deterministic, checksum-pinned, licensed, and
documented.

## Package

The Mojo import is `nami`. The eventual Conda distribution is
`mojo-nami`. Source lives under `src/nami/`, whose
`__init__.mojo` defines the package boundary.

The future FFT-dependent companion uses the import `nami_spectral`, the
distribution `mojo-nami-spectral`, and the sibling source root
`src/nami_spectral/`. It depends explicitly on `mojo-nami` and ShuhaFFT and is
compiled and tested separately. Installing or importing `nami` never requires
that companion.

## Window functions

The first usable slice provides `Float64` Hann, Hamming, and three-term
Blackman windows without ShuhaFFT or another runtime dependency:

```mojo
from nami import WindowNormalization, WindowSampling, hann

var analysis = hann(1024, WindowSampling.PERIODIC)
var filter_design = hann(
    1024,
    WindowSampling.SYMMETRIC,
    WindowNormalization.PEAK,
)
```

`SYMMETRIC` includes both interval endpoints. `PERIODIC` omits the repeated
endpoint for spectral analysis. `FORMULA`, the default normalization, preserves
the defining coefficients; `PEAK` rescales the largest sampled absolute value
to one. Peak normalization raises if every sample is numerically zero rather
than amplifying floating-point residue. Zero length returns an empty list,
length one returns `[1.0]`, and a negative length raises. See
[the window contract](docs/windows.md).

## Direct convolution

The next dependency-free slice provides correctness-first `Float64` linear
convolution:

```mojo
from nami import ConvolutionMode, convolve

var full = convolve([1.0, 2.0, 3.0], [4.0, 5.0])
var same = convolve(
    [1.0, 2.0, 3.0],
    [4.0, 5.0],
    ConvolutionMode.same(),
)
```

FULL is the default. SAME returns the first input's length and left-centers an
even-length kernel. VALID requires the kernel to be no longer than the first
input. Inputs must be non-empty and finite, and arithmetic that produces a
nonfinite sample raises. See [the convolution contract](docs/convolution.md).

## Repository map

- `src/nami/`: library or application source
- `src/nami_spectral/`: future separately packaged ShuhaFFT adapter and
  spectral algorithms; absent until its first working slice
- `tests/`: TestSuite unit, reference-value, and invariant tests
- `examples/`: small compilable usage programs
- `benchmarks/`: reproducible methodology and later benchmark programs
- `docs/`: architecture, design, compatibility, roadmap, and release policy
- `conda.recipe/`: local Rattler build recipe

See [the architecture](docs/architecture.md),
[reference architecture](docs/reference-architecture.md),
[design principles](docs/design.md), and [roadmap](docs/roadmap.md) before
proposing a new dependency or feature.

## License

Licensed under either Apache-2.0 or MIT, at your option.
