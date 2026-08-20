# Nami

> **Experimental — API not yet released.**

Scientific signal processing for Mojo.

## Scope

Nami provides scientific signal-processing algorithms and delegates Fourier transforms to ShuhaFFT instead of embedding an FFT implementation.

The v0.1 work is deliberately staged: dependency-free windows first, direct
convolution and correlation second, and stabilization of that elementary API
third. A small spectral API begins only after those stages and a compatible
ShuhaFFT release; its FFT-dependent imports remain isolated to spectral modules.
The project is independently installable and does not require any application
from the wider ecosystem.

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

## Repository map

- `src/nami/`: library or application source
- `tests/`: TestSuite unit, reference-value, and invariant tests
- `examples/`: small compilable usage programs
- `benchmarks/`: reproducible methodology and later benchmark programs
- `docs/`: architecture, design, compatibility, roadmap, and release policy
- `conda.recipe/`: local Rattler build recipe

See [the architecture](docs/architecture.md), [design principles](docs/design.md),
and [roadmap](docs/roadmap.md) before proposing a new dependency or feature.

## License

Licensed under either Apache-2.0 or MIT, at your option.
