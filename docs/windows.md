# Window functions

Nami provides a dependency-free `Float64` `general_cosine` function and thin
Hann, Hamming, Blackman, Nuttall, Blackman-Harris, and flat-top wrappers.
`general_cosine` accepts an arbitrary-length coefficient span and follows
SciPy's centered-origin convention: coefficients are normally positive, and
odd terms acquire a minus sign when the formula is rewritten over a phase
interval from zero to two pi.

For a length `M > 1`, symmetric sampling evaluates indices `0 ... M-1` with
denominator `M-1`. Periodic sampling uses denominator `M`, so its result is the
first `M` samples of the corresponding symmetric window of length `M+1`.
This makes symmetric sampling suitable for filter design and periodic sampling
suitable for an `M`-sample spectral frame.

Formula normalization evaluates the defining coefficients unchanged. Each
wrapper passes the following coefficients to `general_cosine`:

| Window | Centered-origin coefficients |
| --- | --- |
| Hann | `[0.5, 0.5]` |
| Hamming | `[0.54, 0.46]` |
| Blackman | `[0.42, 0.5, 0.08]` |
| Nuttall | `[0.3635819, 0.4891775, 0.1365995, 0.0106411]` |
| Blackman-Harris | `[0.35875, 0.48829, 0.14128, 0.01168]` |
| Flat top | `[0.21557895, 0.41663158, 0.277263158, 0.083578947, 0.006947368]` |

The Nuttall, Blackman-Harris, and flat-top constants are SciPy-published
constants and are checked against SciPy 1.16.1 fixtures. The flat-top window is
designed for amplitude calibration and is expected to contain negative samples.

Peak normalization divides all sampled values by their largest absolute value,
including for flat top, rather than by the largest signed value. It is
observably different for even symmetric lengths, whose sample grid does not
contain the continuous formula's center. If that sampled peak is at or below
`1e-15`, normalization raises `Error`. The supported formulas have coefficients
of order one, so this fixed absolute rule treats a mathematically zero window as
degenerate and prevents endpoint roundoff from being amplified into unit data.
In particular, symmetric length-two Hann and Blackman windows cannot be peak
normalized; formula normalization still returns their near-zero samples.

All functions return an empty list for length zero and `[1.0]` for length one.
Negative lengths raise `Error`. These edge cases avoid division by zero and
match the mathematical identity-window interpretation used by later operations.

Sampling and normalization are Int-backed nominal values exposed through the
`SYMMETRIC`/`PERIODIC` and `FORMULA`/`PEAK` constants. Their underscore storage
is trusted; callers who mutate it unusually can use `validate()` as an explicit
checkpoint.
