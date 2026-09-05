# Uniform-sample power spectral density and spectrograms

Nami's spectral API estimates one-sided power spectral density (PSD) for
uniformly sampled, finite `Float64` signals. Uniform spectral analysis belongs
in nami. Non-uniform resampling and interpolation belong in nagare; callers must
move samples onto a uniform grid there before using this API.

Import spectral operations explicitly:

```mojo
from nami.spectral import PowerSpectrum, SpectralWorkspace, Spectrogram, periodogram, spectrogram, welch
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

The operation constructs one `SpectralWorkspace` plus the two result lists.
It preserves the input. Reuse a workspace for repeated equal-sized frames to
amortize construction and avoid output allocation.

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
by `1 / (sample_rate * sum(window**2))`, with interior one-sided bins doubled.
Mantissas and exponents are accumulated separately and the final bins are
materialized after averaging by the number of segments.

Welch constructs one `SpectralWorkspace` and two result lists. The plan, Hann
window, real frame, complex spectrum, and per-bin exponents are allocated once
and reused for every segment. It preserves the input.

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
FFT frames in exact power-of-two sample units, and reconstructs densities from
bounded binary mantissas and exponents. Centering retains expanded sums through
`N*x - sum(x)` before division, so a rounded large mean cannot distort the small
difference between adjacent near-maximum samples. The expansion uses fixed
inline storage and does not add heap allocation to workspace calls. It therefore avoids intermediate overflow from
`sample_rate * window_energy`, squared FFT magnitudes, and raw sample sums.
Representable subnormal densities are retained; smaller densities round to zero.
A density or spectrogram time coordinate outside finite `Float64` raises an
error suggesting rescaling or a larger sample rate. A finite rate alone does not
guarantee a representable density or time. Welch accumulates bounded mantissas with per-bin exponents and restores the
final exponent after averaging. Thus neither an overflowing individual frame
nor underflow of individual divided contributions prevents a representable mean. These rules apply to all three
estimators, including zero and near-maximum constant signals.


## Repeated analysis with `SpectralWorkspace`

Construct `SpectralWorkspace(fft_size)` once and preallocate `List[Float64]`
outputs with `workspace.bin_count()` entries. Then use:

- `workspace.frequencies_into(frequencies, sample_rate=1.0)` to fill coordinates;
- `workspace.periodogram_into(frame, power, sample_rate=1.0)` for one frame of
  exactly `workspace.size()` samples; or
- `workspace.welch_into(signal, power, sample_rate=1.0, overlap=None)` for any
  signal at least `workspace.size()` samples long.

The FFT size is immutable. Sample rate, signal length (Welch), and overlap can
change between calls. Every overlap from zero through `size() - 1` is supported.
Methods overwrite the provided list and do not resize or allocate storage. The
workspace owns one FFT plan, the periodic Hann window, one real frame, one
compact complex spectrum, and a per-bin integer exponent list: memory is O(n)
and independent of the number of processed frames. Welch uses the caller's
output list for its accumulation. The one-shot functions delegate to these same
kernels; normalization and DC/Nyquist rules are identical.

The methods require exclusive access to the workspace and output. Construct a
separate workspace per concurrent analysis. Input/configuration errors are
checked before changing output. A numeric overflow may leave partial output;
discard that output and call again with rescaled inputs. The workspace remains
usable after errors. `validate()` is an explicit invariant checkpoint; normal
execution trusts constructed scratch storage. Equality compares FFT size and
ignores overwritten scratch history.

Run `pixi run mojo run -I src examples/spectral_workspace.mojo` for a complete
caller-owned-buffer example. `pixi run --locked bench-spectral` separately times
FFT plan construction, workspace construction, allocating one-shot analysis,
and steady-state processing at FFT sizes 64 and 4096. See the committed
[measurement](../benchmarks/results/spectral-workspace-20260905.md).
