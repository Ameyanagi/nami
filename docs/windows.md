# Window functions

Nami v0.1 begins with a dependency-free `Float64` `general_cosine` function and
thin Hann, Hamming, and three-term Blackman wrappers. `general_cosine` accepts
an arbitrary-length coefficient span and follows SciPy's centered-origin
convention: coefficients are normally positive, and odd terms acquire a minus
sign when the formula is rewritten over a phase interval from zero to two pi.

For a length `M > 1`, symmetric sampling evaluates indices `0 ... M-1` with
denominator `M-1`. Periodic sampling uses denominator `M`, so its result is the
first `M` samples of the corresponding symmetric window of length `M+1`.
This makes symmetric sampling suitable for filter design and periodic sampling
suitable for an `M`-sample spectral frame.

Formula normalization evaluates the defining coefficients unchanged:

- Hann: `0.5 - 0.5 cos(phase)`
- Hamming: `0.54 - 0.46 cos(phase)`
- Blackman: `0.42 - 0.5 cos(phase) + 0.08 cos(2 phase)`

Equivalently, these wrappers pass `[0.5, 0.5]`, `[0.54, 0.46]`, and
`[0.42, 0.5, 0.08]` to `general_cosine`.

Peak normalization divides all sampled values by their largest absolute value.
It is observably different for even symmetric lengths, whose sample grid does
not contain the continuous formula's center. If that sampled peak is at or below
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
