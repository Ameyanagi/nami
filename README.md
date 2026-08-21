# Nami

> **Experimental — API not yet released.**

Scientific signal processing for Mojo.

## Scope

Nami provides scientific signal-processing algorithms and delegates Fourier transforms to ShuhaFFT instead of embedding an FFT implementation.

The v0.1 work is deliberately staged: dependency-free windows first, direct
convolution and correlation second, and stabilization of that elementary API
third. The small spectral API keeps its FFT-dependent imports isolated under
`nami.spectral`. The project is independently installable and does not require
any application from the wider ecosystem.

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

## Quickstart: detrend, Welch PSD, and peak finding

This weekly workflow turns uniformly sampled measurements into a one-sided
power spectral density, then locates prominent spectral lines:

```mojo
from nami import detrend, find_peaks
from nami.spectral import welch
from std.collections import List
from std.math import pi, sin


def main() raises:
    var sample_rate = 800.0
    var samples = List[Float64](capacity=2048)
    for index in range(2048):
        var t = Float64(index) / sample_rate
        samples.append(
            sin(2.0 * pi * 50.0 * t)
            + 0.3 * sin(2.0 * pi * 175.0 * t)
            + 0.002 * Float64(index)
        )

    var stationary = detrend(samples)
    var spectrum = welch(
        stationary,
        sample_rate,
        segment_length=256,
    )
    var peaks = find_peaks(spectrum.power(), min_prominence=0.001)
    var frequencies = spectrum.frequencies()
    var peak_indices = peaks.indices()
    for position in range(len(peaks)):
        print("spectral line:", frequencies[peak_indices[position]], "Hz")
```

The default linear detrend removes the drift; Welch and `find_peaks` then find
the 50 Hz line and its 175 Hz companion. Run the complete example with
`mojo run -I src examples/spectral_workflow.mojo` in an environment where the
`mojo-shuhafft` package is installed. Welch segment lengths must be powers of
two while ShuhaFFT is radix-2 only. `nami.spectral` requires `mojo-shuhafft`,
while importing the elementary `nami` root remains dependency-free.

## Window functions

The first usable slice provides arbitrary-term `Float64` general-cosine windows
plus Hann, Hamming, and three-term Blackman wrappers without ShuhaFFT or another
runtime dependency:

```mojo
from nami import WindowNormalization, WindowSampling, general_cosine, hann
from std.collections import List

var analysis = hann(1024, WindowSampling.PERIODIC)
var nuttall_coefficients: List[Float64] = [
    0.3635819, 0.4891775, 0.1365995, 0.0106411
]
var nuttall = general_cosine(
    1024,
    nuttall_coefficients,
    WindowSampling.PERIODIC,
)
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
    ConvolutionMode.SAME,
)
```

FULL is the default. SAME returns the first input's length and left-centers an
even-length kernel. VALID requires the kernel to be no longer than the first
input. Inputs must be non-empty and finite, and arithmetic that produces a
nonfinite sample raises. See [the convolution contract](docs/convolution.md).

## Repository map

- `src/nami/`: library or application source
- `tests/`: TestSuite unit, reference-value, and invariant tests
- `examples/`: small compilable usage programs
- `benchmarks/`: reproducible methodology and later benchmark programs
- `docs/`: architecture, design, compatibility, roadmap, and release policy
- `conda.recipe/`: local Rattler build recipe

See [the architecture](docs/architecture.md), [design principles](docs/design.md),
the [spectral contract](docs/spectral.md), and [roadmap](docs/roadmap.md) before
proposing a new dependency or feature.

## License

Licensed under either Apache-2.0 or MIT, at your option.
