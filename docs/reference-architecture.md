# Reference architecture

This document turns a pinned review of three mature signal-processing
libraries into an implementation order and public-boundary contract for Nami.
It is architectural research, not a compatibility promise. Nami remains a
small, scientific, Mojo-native package; no reference implementation source is
copied into this repository.

## Research record

The repositories below were shallow-cloned on 2026-08-20 into
`/Users/ryuichi/dev/reference-libraries/nami/`. The local clones are research
inputs only and are not package, test, or build dependencies.

| Reference | Exact revision | License | Boundaries inspected |
| --- | --- | --- | --- |
| [SciPy](https://github.com/scipy/scipy/tree/a2c4d68b3cab98a0e5773ea0016e7c4109da6511/scipy/signal) | `a2c4d68b3cab98a0e5773ea0016e7c4109da6511` | [BSD-3-Clause](https://github.com/scipy/scipy/blob/a2c4d68b3cab98a0e5773ea0016e7c4109da6511/LICENSE.txt) | [`signal` facade](https://github.com/scipy/scipy/blob/a2c4d68b3cab98a0e5773ea0016e7c4109da6511/scipy/signal/__init__.py), [`windows`](https://github.com/scipy/scipy/tree/a2c4d68b3cab98a0e5773ea0016e7c4109da6511/scipy/signal/windows), [`_signaltools`](https://github.com/scipy/scipy/blob/a2c4d68b3cab98a0e5773ea0016e7c4109da6511/scipy/signal/_signaltools.py), [`_upfirdn`](https://github.com/scipy/scipy/blob/a2c4d68b3cab98a0e5773ea0016e7c4109da6511/scipy/signal/_upfirdn.py), [`_spectral_py`](https://github.com/scipy/scipy/blob/a2c4d68b3cab98a0e5773ea0016e7c4109da6511/scipy/signal/_spectral_py.py), [`_short_time_fft`](https://github.com/scipy/scipy/blob/a2c4d68b3cab98a0e5773ea0016e7c4109da6511/scipy/signal/_short_time_fft.py), filter design, and peak finding |
| [DSP.jl](https://github.com/JuliaDSP/DSP.jl/tree/7c798756cca39251da14bb5d38146feb2cdd1717) | `7c798756cca39251da14bb5d38146feb2cdd1717` (`v0.8.6`) | [MIT](https://github.com/JuliaDSP/DSP.jl/blob/7c798756cca39251da14bb5d38146feb2cdd1717/LICENSE.md) | [`DSP` facade](https://github.com/JuliaDSP/DSP.jl/blob/7c798756cca39251da14bb5d38146feb2cdd1717/src/DSP.jl), windows, convolution/correlation, periodograms, filter coefficients/design/application, and [stateful FIR/resampling](https://github.com/JuliaDSP/DSP.jl/blob/7c798756cca39251da14bb5d38146feb2cdd1717/src/Filters/stream_filt.jl) |
| [dasp](https://github.com/RustAudio/dasp/tree/d0892971a3b72dee9b3ff0d16f94b0962605e858) | `d0892971a3b72dee9b3ff0d16f94b0962605e858` | [MIT](https://github.com/RustAudio/dasp/blob/d0892971a3b72dee9b3ff0d16f94b0962605e858/LICENSE-MIT) OR [Apache-2.0](https://github.com/RustAudio/dasp/blob/d0892971a3b72dee9b3ff0d16f94b0962605e858/LICENSE-APACHE) | [workspace crates](https://github.com/RustAudio/dasp/blob/d0892971a3b72dee9b3ff0d16f94b0962605e858/Cargo.toml), [feature-gated facade](https://github.com/RustAudio/dasp/blob/d0892971a3b72dee9b3ff0d16f94b0962605e858/dasp/src/lib.rs), `Signal`, windows, interpolation, ring buffers, peak, and RMS |

The revision is the unit of evidence. A future refresh must add a new dated
record or update this table and re-review the changed contracts; a moving
default branch is not sufficient provenance.

## What the references teach

### SciPy: rich batch semantics, intentionally broad facade

SciPy exposes convolution, correlation, filter application and design,
resampling, peak finding, spectral estimators, and short-time transforms from a
large `scipy.signal` namespace, with windows in a discoverable subnamespace.
Its implementation separates direct/FFT signal tools, polyphase primitives,
spectral functions, a stateful short-time transform, filter design, and peak
finding even though much of the API is re-exported from one facade.

Nami adopts the precise semantic questions made visible by that API: input
roles, FULL/SAME/VALID shapes, correlation lags, direct versus FFT methods,
Fourier versus polyphase resampling, one- versus two-sided spectra, padding,
boundary extension, detrending, scaling, and invertibility conditions. Nami
does not adopt the size of the facade, N-dimensional `axis` polymorphism, a
universal array abstraction, or silent method selection in its first releases.

### DSP.jl: domain modules plus explicit processing state

DSP.jl has a small top-level module that re-exports focused domains including
windows, periodograms, filters, and estimation. Its filter package separates
coefficient representations, design, responses, batch filtering, and stateful
FIR/polyphase filtering. Its resampling convenience API is backed by an object
that owns phase and history across calls.

Nami adopts the separation between coefficient values and processing state,
and the rule that a chunked processor must expose ownership of history, phase,
and reset behavior. Nami does not adopt FFTW as an ambient dependency, broad
re-export of all subpackages, or filter-design breadth before filter
application contracts are stable.

### dasp: composable stream state, audio-specific root model

dasp is a workspace of narrowly scoped crates, assembled by a feature-gated
facade. Its `Signal` abstraction composes stateful frame streams, and its
windowing, interpolation, ring-buffer, peak, and RMS components demonstrate
that streaming algorithms need explicit state and bounded storage.

Nami adopts the modularity lesson and the distinction between a reusable
processor and a one-shot convenience function. It rejects `Sample`, `Frame`,
channel-layout, infinite-signal, audio graph, and device-oriented abstractions
as Nami's root data model. Nami processes finite scientific sequences first;
audio infrastructure is explicitly outside its scope.

## Architectural boundary

Nami has two one-way, separately compiled packages:

```text
`nami` / `mojo-nami` dependency-free elementary package
  windows
  direct convolution and correlation
  FIR/IIR application
  polyphase rational resampling
  smoothing and peak finding

`nami_spectral` / `mojo-nami-spectral` companion package
  depends on `nami` and the ShuhaFFT adapter
  spectra and periodograms
  STFT/ISTFT
  later FFT convolution and Fourier resampling
```

Elementary modules must not import `nami_spectral` or ShuhaFFT. The root
`nami` package exports only stable elementary symbols, and `src/nami/` is
precompiled by itself into the `nami` artifact. Importing, precompiling,
testing, and packaging it must work when ShuhaFFT is absent.

FFT-dependent source lives in the sibling `src/nami_spectral/` top-level Mojo
package and is precompiled into a separate `nami_spectral` artifact. Its
`mojo-nami-spectral` distribution depends explicitly on compatible releases of
`mojo-nami`, `mojo-shuhafft`, and the exact Mojo compiler. It may import `nami`
and ShuhaFFT; dependency direction never reverses. This is a second package,
not an optional nested subpackage inside the compiled `nami` directory.
The split is required by the pinned Mojo 1.0 compiler: precompiling a package
directory validates its nested packages, so an unresolved ShuhaFFT import in
`src/nami/spectral/` would fail the dependency-free core build even when the
root `__init__.mojo` did not import it.

An algorithm that can use either direct or FFT execution does not erase this
boundary. The first implementation exposes the direct algorithm in its owning
elementary module. A later FFT implementation lives in `nami_spectral` and uses
an explicit method or distinct function. Automatic threshold selection is not
added until both methods have identical public semantics, measured crossover
data, and an elementary-only installation remains testable.

The intended source topology is:

```text
src/nami/
  __init__.mojo                 small elementary facade
  _validation.mojo              shared finite/length checks, not exported
  convolution.mojo              direct linear convolution
  correlation.mojo              direct cross-correlation and lag indices
  windows/                      pure window generation
  filters/
    __init__.mojo               elementary filter API
    coefficients.mojo           validated coefficient values
    fir.mojo                    batch FIR and stateful FIR processor
    iir.mojo                    batch IIR and stateful IIR processor
  resampling/
    __init__.mojo
    polyphase.mojo              rational FIR resampling
  smoothing/                    local/statistical smoothers, one contract each
  peaks/                        peak locations and measured properties

src/nami_spectral/              separate Mojo package and artifact
  __init__.mojo                 explicit spectral facade
  _shuhafft_adapter.mojo        normalization and planning translation
  spectrum.mojo                 bins, periodogram, later Welch
  stft.mojo                     one-shot and reusable short-time transforms

conda.recipe/recipe.yaml        builds only mojo-nami from src/nami
conda.recipe/spectral/          later independent mojo-nami-spectral recipe
```

Directories are created only with their first working public slice. Empty
placeholder modules and speculative root exports are not architecture.
`src/nami_spectral/` and its recipe therefore do not exist until
NAMI-SPEC-001 can compile and test a real adapter slice.

## Inputs, outputs, and memory

The first stable APIs accept finite one-dimensional `List[Float64]` values and
return new owning lists or a documented result struct. This matches the
implemented windows and convolution surface and avoids inventing a Nami array.
Inputs are logically read-only and are preserved.

Borrowed-buffer overloads are deferred until a downstream caller demonstrates
that allocation or ownership transfer is material. When Mojo's stable APIs and
call-site evidence justify them, a read-only span/buffer overload may share the
same internal kernel. It must not change numerical or error semantics. Nami
does not add an array wrapper, hidden copy-on-write behavior, strided
N-dimensional axes, or generic `Float32` solely to imitate another ecosystem.

An in-place or caller-buffer API must say all of the following in its public
contract: required capacity, aliasing rules, initialized range, behavior on an
error, and whether processor state advances. Such an API is a measured
optimization, not an overload of the pure function.

Length arithmetic is validated before allocation. Inputs that are
mathematically undefined when empty reject emptiness; window length zero keeps
its existing empty result. Returned lengths, alignment, delays, and lag ranges
are part of the API rather than incidental implementation details.

## Domain ownership and API shape

### Windows

Window functions are pure allocation APIs owned by `nami.windows`. The current
sampling and normalization types remain nominal and total. A later
`fill_window` API is justified only by benchmarked repeated allocation and must
preserve the formula, singleton, and degenerate-normalization contracts.

### Convolution and correlation

`convolve` and `correlate` are one-shot functions. Direct scalar execution is
the normative numerical order for v0.1. The first input is the signal and the
second is the kernel/template; SAME length and VALID admissibility are not
made commutative merely because FULL convolution is mathematically
commutative.

Correlation must land with `correlation_lags`, a written definition of whether
the second sequence is conjugated/reversed, the zero-lag index, and the exact
even-length SAME slice. Because the same three output shapes apply to both
operations, the correlation issue should replace the unreleased
`ConvolutionMode` name with a total shared `OutputMode` rather than publish two
duplicate mode types. This migration must update every public example and
compile fixture before the v0.1 surface freezes.

FFT convolution, overlap-add, and an automatic method chooser are spectral
features. They cannot be imported or selected by elementary `convolve`.

### Filters

Filter coefficients and processor state are different types:

- `FIRCoefficients` owns a validated, non-empty finite tap sequence.
- `IIRCoefficients` owns finite numerator and denominator sequences and a
  finite nonzero leading denominator coefficient.
- `FIRFilter` and `IIRFilter` own coefficients plus mutable history.
- A batch `filter_fir` or `filter_iir` convenience function creates zero
  initial state, processes one sequence, and returns a new owning output.
- Stateful `process` reads and preserves a caller-owned chunk, returns a new
  owning output, and advances processor history. `reset` returns to the
  documented zero state. A documented `state_snapshot` returns an owning copy
  for ordinary inspection and restart workflows.

Mojo 1.0 does not enforce privacy for underscore-prefixed struct fields. The
types cannot rely on coefficients, history, phase, or scratch storage staying
behind methods. Every public observation therefore validates the complete
reachable representation before indexing:

- coefficient collections remain non-empty, finite, and valid for the chosen
  recurrence;
- history lengths still match the current coefficient lengths;
- a resampler's reduced factors, phase, tap count, and history agree; and
- a short-time transform's configuration, window, frame history, plan
  metadata, and scratch capacity agree.

Valid same-shape coefficient mutation denotes a processor with the new finite
coefficients and existing input history. A shape change makes the current
history invalid: `process` raises without advancing, while `reset` may recover
by transactionally constructing correctly sized zero history after validating
the new coefficients. Exposed state is an implementation limitation, not a
license for unchecked indexing.

Stateful operations use commit-last semantics. They validate the entire input
chunk and current representation, compute output plus next history/phase in
local owning values, validate the result, and only then replace processor
state. Allocation failure, non-finite arithmetic, or any validation error
leaves every field observably unchanged. Mutation/error tests reach the same
fields a caller can reach and assert both rejection and state preservation.

Direct-form choice, coefficient normalization, initial-condition length, and
output behavior on arithmetic overflow are public numerical contracts. Filter
application does not claim that arbitrary coefficients describe a stable
system. Filter design, forward-backward filtering, and second-order sections
are separate later issues.

### Resampling

The first scientific resampler is rational polyphase FIR resampling, not
Fourier resampling. `resample_poly(signal, up, down, taps)` is a batch
convenience API. `up` and `down` are positive, reduced by their greatest common
divisor, and determine an exact output-length rule. `taps` is caller-supplied
validated `FIRCoefficients`, borrowed read-only and preserved by the call. The
function never designs, renormalizes, or replaces it.

The first contract interprets taps at the reduced upsampled rate and applies
them in the provided order with no implicit gain factor. It requires an odd tap
count, uses the middle tap index as the explicit alignment origin, uses zero
extension outside the finite input, returns an empty output for empty input,
and returns exactly
`ceil(input_length * up / down)` samples after checked length arithmetic.
Anti-aliasing and DC gain are properties of the coefficients supplied by the
caller, not hidden design policy. Hand fixtures state the taps as well as the
rate factors, so there is no ambient default filter.

A later `PolyphaseResampler` takes ownership of an `FIRCoefficients` value at
construction and owns taps, input history, and phase for chunked processing.
Callers who also need the coefficient value retain an explicit copy. Tests must
prove that concatenated chunk output equals batch output under an explicit
flush/end-of-stream policy, including after reachable mutation and reset.
Arbitrary floating-rate conversion is not inferred from the rational API.

Fourier resampling assumes a periodic signal and requires ShuhaFFT. It belongs
in `nami_spectral`, has a distinct name, and is never a silent fallback for
polyphase resampling.

### Spectra and STFT

The ShuhaFFT adapter is the only module that translates Nami conventions into
FFT direction, real-transform shape, and normalization. Other spectral modules
depend on the adapter, not on ShuhaFFT internals. The adapter is integration
code, not a second transform implementation.

One-shot `spectrum`/`periodogram` and `stft` functions take explicit validated
configuration values. A reusable `ShortTimeTransform` may later own the
window, hop, ShuhaFFT plan, and scratch buffers. It is useful for repeated or
chunked calls; it is not required for a single transform. Its public methods
apply the same reachable-state revalidation and commit-last rule as elementary
stateful processors.

Before implementation, the contract fixes sample-rate units, frequency-bin
ordering, one- versus two-sided output, detrending, window normalization,
power/amplitude density scaling, frame centering, boundary padding, hop and
overlap, and ISTFT reconstruction conditions. Inverse STFT rejects a
configuration that cannot satisfy its documented overlap-add denominator
rather than returning silently corrupted data.

### Smoothing and peaks

Smoothing and peak finding remain dependency-free, pure batch APIs. A smoother
owns its boundary rule and kernel/parameter meaning; it does not silently call
an FFT. Peak results use a documented result struct when returning properties
such as prominence or width, while the minimal location-only operation should
not allocate unused properties. Streaming envelope detectors and audio meters
are not peak-finding APIs.

## Minimal public surface

The package root stays limited to mature elementary conveniences. Today it is:

```mojo
from nami import (
    ConvolutionMode,
    WindowNormalization,
    WindowSampling,
    blackman,
    convolve,
    hamming,
    hann,
)
```

The correlation issue may make the intentional pre-v0.1 `ConvolutionMode` to
`OutputMode` migration described above, then add only:

```mojo
from nami import OutputMode, correlate, correlation_lags
```

Broader domains remain explicit:

```mojo
from nami.filters import FIRCoefficients, FIRFilter, filter_fir
from nami.resampling import PolyphaseResampler, resample_poly
from nami.peaks import Peak, find_peaks
from nami_spectral import Spectrum, periodogram
from nami_spectral import STFTConfig, ShortTimeTransform, stft
```

These are target names, not placeholders or present-day exports. Each appears
only with its implementation, tests, example, and written contract. Root
promotion requires repeated cross-domain use; discoverability alone is not a
reason to re-export a type.

## Errors and numerical contracts

All public numeric entry points validate their complete observable input before
indexing or allocation. Publicly mutable collection inputs are re-read for the
call. Reusable processors cannot assume their reachable fields stayed behind
methods: they validate structural, finite, and cross-state invariants at every
public operation.

Common rules are:

- reject NaN and infinity in sample, coefficient, rate, and configuration
  inputs unless a function explicitly defines them;
- reject a nonfinite intermediate or returned sample rather than emit NaN or
  infinity from finite inputs;
- validate every derived length and index calculation against `Int` overflow
  before allocating;
- require a finite positive sample rate, positive frame and hop lengths,
  positive resampling factors, and a finite nonzero IIR leading denominator;
- state accumulation order and tolerance where floating-point reassociation
  can change a result;
- keep direct algorithms deterministic and do not select another method from
  machine-dependent timing;
- specify whether an error leaves state unchanged; the default for a stateful
  processor is validation and local next-state construction before a single
  commit-last state advance;
- distinguish mathematically invalid configuration from finite arithmetic
  overflow in error text so tests and callers can diagnose both.

No initial filter release promises stability detection for arbitrary IIR
coefficients. No spectral release claims reconstruction until its window/hop,
padding, normalization, and overlap-add invariants have round-trip tests.

## Validation corpus

Every issue adds analytic/reference fixtures, invariants, mutation/error
tests, a public-import compile example, and package smoke. Expected values are
derived independently from written equations or tiny hand calculations; no
reference source or test corpus is copied.

| Domain | Required reference and invariant coverage |
| --- | --- |
| Windows | Existing coefficient fixtures; zero/singleton behavior; symmetry; periodic extension; peak normalization; invalid length and degenerate peak |
| Convolution | Hand calculations; impulses; constants; FULL commutativity; SAME/VALID first-input roles; finite overflow; input preservation |
| Correlation | Hand calculations with signed lags; impulse lag; autocorrelation symmetry; zero-lag dot product; relation to convolution with a reversed second input; unequal/even lengths |
| FIR/IIR | Impulse, step, and constant signals; hand recurrence; zero initial state; batch versus chunk equivalence; reset and owning snapshots; reachable coefficient/history mutation; coefficient and state-length errors; overflow without partial state advance |
| Resampling | Explicit caller-supplied tap tables; identity ratio; GCD-equivalent ratios; impulse alignment; known sinusoid below cutoff with separately justified anti-alias taps; exact output length; no implicit gain/design; batch versus irregular chunks plus flush; invalid factors and reachable state mutation |
| Spectrum | Exact-bin sine and DC; bin frequencies; one-/two-sided lengths; amplitude/power scaling; Parseval relation within a declared tolerance |
| STFT/ISTFT | Frame count and centering; exact-bin frames; one-shot versus reusable plan; COLA/NOLA edge cases; round trip under supported configurations; irregular chunks and final flush |
| Peaks/smoothing | Plateaus, endpoints, ties, minimum distance, prominence/width definitions; constant and impulse smoothing; boundary behavior; input preservation |

Reference comparisons to the pinned SciPy or DSP.jl APIs may be generated in a
development-only script, with the reference revision and parameters recorded.
Generated numeric fixtures must be small, reviewable, and committed with their
derivation; Python or Julia is never required to build, import, test, or use
Nami.

## Benchmark corpus

Benchmarks report methodology and raw measurements, never unqualified
superiority. Each run records CPU, OS, Mojo version, compiler options, warmup,
iterations, allocation policy, and data generation seed.

- windows: small, medium, and large lengths, formula versus peak normalization;
- convolution/correlation: asymmetric `(N, M)` grids including tiny kernels,
  similar lengths, and all output modes;
- FIR/IIR: samples per call, tap/section count, one-shot versus varied chunk
  sizes, and processor reuse;
- rational resampling: reduced and unreduced ratios, tap count, short and long
  signals, batch and chunked operation;
- spectra/STFT: FFT/frame lengths, hop sizes, batch frame counts, plan reuse,
  and allocation-separated throughput;
- peaks/smoothing: sparse/dense peaks, plateau lengths, smoothing width, and
  long constant/adversarial sequences.

Measurements may later identify a direct/FFT crossover, but the crossover is
not an API guarantee and cannot weaken the explicit dependency boundary.

## Adopted and rejected ideas

| Decision | Adopt | Reject or defer |
| --- | --- | --- |
| Package surface | Focused domain modules and a small stable root | SciPy-sized flat facade or speculative re-exports |
| Data model | Mojo-native finite one-dimensional collections | A Nami array, audio `Frame`, channel graph, or N-D `axis` surface |
| Execution | Explicit direct elementary and explicit FFT spectral algorithms | Silent `auto` method selection before semantic parity and benchmarks |
| State | Pure batch functions plus operation-time-validated, commit-last processors where chunks require history/phase | Hidden global caches, privacy assumptions, unchecked reachable state, or mutation inside nominally pure calls |
| Filters | Separate coefficients, state, application, and later design | Shipping a broad filter-design catalogue before application contracts |
| Resampling | Rational polyphase FIR with borrowed caller-supplied taps first; distinct Fourier resampling later | Hidden filter design or one ambiguous `resample` whose assumptions change by input size |
| FFT ownership | A narrow ShuhaFFT adapter in the separately compiled `nami_spectral` package | Bundled FFT implementation, an optional nested package, or ShuhaFFT imported from `src/nami/` |
| Optimization | Preserve a scalar normative path and optimize measured kernels | Benchmark-driven semantic changes or unsupported speed claims |

## Issue lanes and order

Issues are sized to merge with their complete contract. An issue cannot add a
public placeholder for a later issue. Only the v0.1 core is one serial release
sequence; after it freezes, the filter, resampling, utility, and externally
gated spectral lanes are independent:

```text
NAMI-REF-001
      ↓
NAMI-CORE-003
      ↓
NAMI-CORE-004  ← v0.1 ends
   ├── NAMI-FILT-001 → NAMI-FILT-002
   ├── NAMI-RSMP-001 → NAMI-RSMP-002
   ├── NAMI-UTIL-001
   └── NAMI-SPEC-001 → 002 → 003 → 004 → NAMI-PERF-001
           ↑
     compatible tagged ShuhaFFT
```

### v0.1 core sequence

1. **NAMI-REF-001 — Reference architecture.** Land this research record,
   package boundaries, API ownership, validation corpus, and issue lanes.
2. **NAMI-CORE-003 — Direct correlation.** Define signed lags and unequal/even
   shape rules; migrate the unreleased shape type to total `OutputMode`;
   implement direct `correlate` plus `correlation_lags`; add hand fixtures,
   convolution relation properties, example, benchmark cases, and package
   smoke.
3. **NAMI-CORE-004 — Elementary v0.1 freeze.** Exercise windows/convolution/
   correlation from an independent installed consumer; record allocation and
   tolerance contracts; decide borrowed-buffer overloads from evidence; freeze
   root exports. This closes v0.1.

### Post-v0.1 filter lane

- **NAMI-FILT-001 — FIR coefficients and application.** Add validated
  coefficients, zero-state batch filtering, stateful chunk processor, reset,
  state snapshots, operation-time reachable-state validation, commit-last
  errors, mutation tests, and batch/chunk equivalence. No design API.
- **NAMI-FILT-002 — IIR application.** Depends on NAMI-FILT-001's ownership and
  transaction contracts. Choose and document the recurrence; add coefficient
  normalization, initial/final state, batch and stateful processing,
  cross-state mutation and extreme-value tests, and no stability claim. Defer
  SOS and design.

### Post-v0.1 resampling lane

- **NAMI-RSMP-001 — Caller-filtered rational polyphase batch slice.** Accept
  borrowed validated `FIRCoefficients`; specify reduced-rate tap meaning, no
  implicit design/gain, checked ceiling length, middle-tap alignment, boundary
  extension, and GCD reduction; implement `resample_poly` with hand and
  separately justified anti-alias fixtures.
- **NAMI-RSMP-002 — Stateful polyphase processor.** Depends on NAMI-RSMP-001.
  Take ownership of coefficients; add chunk history/phase, cross-state
  validation, commit-last processing, flush behavior, reset, snapshots,
  mutation tests, and arbitrary-chunk equivalence without changing the batch
  result.

### Post-v0.1 utility lane

- **NAMI-UTIL-001 — One peak or smoothing slice.** Select one downstream-
  justified operation, define boundary/tie semantics, and land it end to end;
  do not create both broad namespaces at once.

### ShuhaFFT-gated spectral companion lane

- **NAMI-SPEC-001 — Separate package and adapter contract.** Begins only after
  a compatible tagged ShuhaFFT release. Create working `src/nami_spectral/`
  source, precompile it separately, and package it as
  `mojo-nami-spectral` with explicit `mojo-nami` and `mojo-shuhafft`
  dependencies. Translate plan and normalization semantics; add a dependency-
  free core CI/package lane and a separately installed spectral CI/package
  smoke. Do not add `src/nami/spectral/`.
- **NAMI-SPEC-002 — Real-signal periodogram.** Depends on NAMI-SPEC-001. Define
  bins, units, one-sided scaling, windowing, and sample-rate validation; add
  exact-bin and energy fixtures.
- **NAMI-SPEC-003 — One-shot STFT/ISTFT.** Define configuration, frames,
  centering, padding, overlap-add conditions, output ownership, and round-trip
  tolerances before implementation.
- **NAMI-SPEC-004 — Reusable short-time transform.** Own plan and scratch
  buffers; add operation-time cross-state validation, commit-last repeated/
  chunked execution and flush, mutation tests, and parity with the one-shot API.
- **NAMI-PERF-001 — Explicit FFT convolution.** Add it only to
  `nami_spectral` after semantic parity with direct convolution. Consider an
  automatic chooser in a separate issue after reproducible crossover data.

## Non-goals

This architecture does not authorize audio devices, codecs, media transport,
real-time scheduling, channel graphs, plotting, interpolation, optimization, a
Nami-specific array, N-dimensional signal APIs, a second FFT, GPU kernels,
filter-design completeness, or source compatibility with SciPy, DSP.jl, or
dasp. Those projects are references for boundary questions, not templates to
port.
