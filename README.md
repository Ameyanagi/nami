# Nami

> **Experimental — API not yet released.**

Scientific signal processing for Mojo.

## Install

For an existing Pixi project, add Nami's package channel to `pixi.toml`:

```toml
[workspace]
channels = [
    "https://ameyanagi.github.io/mojo-channel",
    # Keep your project's other channels here.
]
```

Then add the package:

```sh
pixi add mojo-nami
```

The `mojo-nami` package declares `mojo-shuhafft` as a runtime dependency from
the same channel, so `nami.spectral` is available without a separate install.

To work from a source checkout, install the locked environment and run its
validation and example tasks:

```sh
pixi install --locked
pixi run check
pixi run example
```

Run your own Mojo file against the checkout with the full command:

```sh
pixi run mojo run -I src your_file.mojo
```

## Quickstart

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
`pixi run mojo run -I src examples/spectral_workflow.mojo` (the pixi environment
already includes `mojo-shuhafft`).

ShuhaFFT supports arbitrary-length complex transforms through Bluestein's
algorithm, but its compact reusable `RealFFTPlan` remains radix-2. Nami's
real-signal spectral APIs use that plan, so `periodogram` requires the whole
signal length to be a power of two, while `welch` and `spectrogram` require a
power-of-two `segment_length`; all FFT lengths must be at least two.
Invalid-length errors report the supplied length and suggest the nearest valid
length or lengths.

## What's in the box

- [`hann`, `hamming`, `blackman`, `nuttall`, `blackman_harris`, `flattop`, and
  `general_cosine`](docs/windows.md) create `Float64` windows;
  `WindowSampling` and `WindowNormalization` control their conventions.
- [`convolve` and `correlate`](docs/convolution.md) perform direct linear
  operations, with output shape selected by `ConvolutionMode`.
- [`detrend`](docs/detrend.md) removes a constant or linear trend selected by
  `DetrendKind`.
- [`savgol_filter` and `savgol_coefficients`](docs/savgol.md) provide
  Savitzky–Golay smoothing and coefficient generation.
- [`find_peaks`](docs/peaks.md) locates and filters local maxima and returns
  complete prominence/width metadata; `find_peaks_into` reuses caller-owned
  `Peaks` and `PeakWorkspace` storage for repeated analysis.
- [`periodogram`, `welch`, and `spectrogram`](docs/spectral.md), imported from
  `nami.spectral`, estimate one-sided power spectral density. `spectrogram`
  returns borrowed coordinates plus a contiguous frame-major power matrix.

## Window functions

The first usable slice provides arbitrary-term `Float64` general-cosine windows
plus the named window wrappers without requiring callers to work with the
underlying coefficients:

```mojo
from nami import WindowNormalization, WindowSampling, general_cosine, hann
from std.collections import List


def main() raises:
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
    print("window lengths:", len(analysis), len(nuttall), len(filter_design))
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
from std.collections import List


def main() raises:
    var signal: List[Float64] = [1.0, 2.0, 3.0]
    var kernel: List[Float64] = [4.0, 5.0]
    var full = convolve(signal, kernel)
    var same = convolve(signal, kernel, ConvolutionMode.SAME)
    print("full:", full, "same:", same)
```

FULL is the default. SAME returns the first input's length and left-centers an
even-length kernel. VALID requires the kernel to be no longer than the first
input. Inputs must be non-empty and finite, and arithmetic that produces a
nonfinite sample raises. See
[the convolution contract](docs/convolution.md).

## Scope and package

Nami provides scientific signal-processing algorithms and delegates Fourier
transforms to ShuhaFFT instead of embedding an FFT implementation. Its
dependency-free elementary API is exported from `nami`, while FFT-dependent
imports stay isolated under `nami.spectral`.

The Mojo import is `nami`, the Conda distribution is `mojo-nami`, and source
lives under `src/nami/`. The project is independently installable and does not
require an application from the wider ecosystem.

## Repository map

- `src/nami/`: library source
- `tests/`: TestSuite unit, reference-value, and invariant tests
- `examples/`: small compilable usage programs
- `benchmarks/`: reproducible methodology and benchmark programs
- `docs/`: architecture, design, compatibility, roadmap, and release policy
- `conda.recipe/`: local Rattler build recipe

See [the architecture](docs/architecture.md), [design principles](docs/design.md),
[compatibility policy](docs/compatibility.md), and [roadmap](docs/roadmap.md)
before proposing a new dependency or feature. The contract for every public
operation is linked from [What's in the box](#whats-in-the-box).

## License

Licensed under either Apache-2.0 or MIT, at your option.
