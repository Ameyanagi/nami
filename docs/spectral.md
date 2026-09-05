# Uniform-sample power spectral density and spectrograms

Nami's spectral API estimates one-sided power spectral density (PSD) for
uniformly sampled, finite `Float64` signals. Uniform spectral analysis belongs
in nami. Non-uniform resampling and interpolation belong in nagare; callers must
move samples onto a uniform grid there before using this API.

Import spectral operations explicitly:

```mojo
from nami.spectral import PowerSpectrum, Spectrogram, periodogram, spectrogram, welch
```

The elementary `nami` root remains FFT-free. `nami.spectral` is the only nami
package that depends on the installed `mojo-shuhafft` package.

## Result and bin contract

`PowerSpectrum` owns parallel frequency and power lists. Its `frequencies()` and
`power()` accessors return non-owning spans, and `len(result)` is the number of
bins. The lists always have the same length; construction validates this
invariant, and `validate()` provides an explicit checkpoint after unusual direct
field mutation.

`Spectrogram` owns frame-center times, frequency bins, and one contiguous power
matrix. Its `times()`, `frequencies()`, and `power()` accessors return borrowed
spans. `frame_count()` and `bin_count()` describe the matrix. Storage is
frame-major, so power for `(frame_index, bin_index)` is at

```text
power[frame_index * bin_count + bin_index]
```

This flat contract transfers directly to plotting and image code without a
nested collection or per-row allocation.

All estimators return `n_fft // 2 + 1` one-sided bins in DC-first,
ascending-frequency order. Bin `k` is exactly

```text
k * sample_rate / n_fft
```

so the last bin is the Nyquist frequency. Power values are density-scaled and
have units of signal squared per hertz. With a bin spacing
`df = sample_rate / n_fft`, summing `power[k] * df` approximates the detrended
signal variance.

The underlying ShuhaFFT forward transform is unnormalized. For a window `w`,
the two-sided density normalization is

```text
scale = 1 / (sample_rate * sum(w[i] * w[i]))
power[k] = scale * abs(fft[k])**2
```

The one-sided result doubles every bin except DC and Nyquist. The supported FFT
lengths are even powers of two, so Nyquist is always present and is never
doubled.

## `periodogram`

`periodogram(signal, sample_rate=1.0)` matches the defaults of
`scipy.signal.periodogram` for this curated API:

- constant detrending of the entire signal;
- a rectangular window;
- a one-sided density spectrum; and
- no averaging.

Here `n_fft` is the signal length, and the density scale simplifies to
`1 / (sample_rate * n_fft)`.

The signal length must be a power of two at least 2 because Nami uses
ShuhaFFT's compact reusable `RealFFTPlan`, which remains radix-2 even though
ShuhaFFT's complex transform API also supports arbitrary lengths through
Bluestein's algorithm. Invalid non-power-of-two lengths raise an error that
reports the supplied length and suggests the nearest lower and higher valid
powers of two. Lengths below 2 report 2 as the smallest valid length.

The operation allocates one real FFT plan and its tables, one detrended signal
list, one compact complex FFT result, and the two result lists. It preserves the
input.

## `welch`

`welch(signal, sample_rate=1.0, *, segment_length=256, overlap=None)` fixes the
following choices to the defaults of `scipy.signal.welch`:

- a periodic Hann window;
- constant detrending independently within every segment;
- a one-sided density spectrum;
- mean averaging; and
- overlap of `segment_length // 2` when omitted.

These choices are baked into the curated API rather than exposed as knobs. The
segment step is `segment_length - overlap`, and the number of complete segments
is

```text
(len(signal) - segment_length) // step + 1
```

Trailing samples that do not complete a segment are ignored. Each segment is
detrended, multiplied by the periodic Hann window, transformed, density-scaled
by `1 / (sample_rate * sum(window**2))`, and accumulated. The accumulated bins
are divided by the number of segments, then the interior one-sided bins are
doubled.

Welch constructs one `RealFFTPlan[DType.float64]`, allocates its tables once,
and reuses it for every segment. Its Hann window, accumulated result, real frame
buffer, and compact complex spectrum buffer are also allocated once; the two
work buffers are overwritten for each segment. It preserves the input.

## `spectrogram`

`spectrogram(signal, sample_rate=1.0, *, segment_length=256, overlap=None)`
uses the same periodic Hann window, independent constant detrending, one-sided
density normalization, and default half overlap as `welch`. Instead of averaging
the complete frames, it returns every frame in a `Spectrogram`.

For frame start sample `start`, its time coordinate is the exact window center:

```text
(start + segment_length / 2) / sample_rate
```

Frequencies are the same DC-first bins as `PowerSpectrum`. Every power value has
units of signal squared per hertz. Interior bins are doubled for a one-sided
density; DC and Nyquist are not. The arithmetic mean of each bin over all
spectrogram frames therefore equals `welch` with the same arguments.

One `RealFFTPlan`, real frame buffer, and compact spectrum buffer are allocated
once and reused across all frames. The result allocates its time and frequency
coordinates and one flat `frame_count * bin_count` power list. No allocation is
performed inside the frame loop. Trailing samples that cannot complete a frame
are ignored.

Run `pixi run mojo run -I src examples/spectrogram.mojo` for a small signal whose
dominant frequency changes over time.

## Errors and numerical agreement

All three estimators raise when `sample_rate` is not positive and finite or when
any input sample is not finite. `periodogram` additionally enforces its
signal-length constraint. `welch` and `spectrogram` raise when:

- `segment_length` is not a power of two at least 2, with nearest valid powers
  suggested for non-power-of-two values;
- the signal is shorter than `segment_length`, reporting both lengths; or
- `overlap` is outside `0 <= overlap < segment_length`.

PSD results are checked against fixtures generated by SciPy 1.16.1 and NumPy
2.3.2. Spectrogram frames are checked against an independent direct-DFT oracle
and their arithmetic mean is differentially checked against Welch.
Because Mojo and NumPy can synthesize the same trigonometric signal with
different last-bit rounding, fixture comparisons use a mixed per-bin tolerance:
absolute error no greater than `max(1e-9, 1e-9 * abs(expected))`.

The implementation computes frequencies as `(k / n_fft) * sample_rate`, centers
FFT frames in normalized sample units, and reconstructs densities from bounded
binary mantissas and exponents. It therefore avoids intermediate overflow from
`sample_rate * window_energy`, squared FFT magnitudes, and raw sample sums.
Representable subnormal densities are retained; smaller densities round to zero.
A density or spectrogram time coordinate outside finite `Float64` raises an
error suggesting rescaling or a larger sample rate. A finite rate alone does not
guarantee a representable density or time. Welch divides each frame contribution
by its segment count before accumulation, so an overflowing individual frame
need not prevent a representable average. These rules apply to all three
estimators, including zero and near-maximum constant signals.
