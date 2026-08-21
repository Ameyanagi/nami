# Peak finding

`find_peaks(signal, *, min_height, min_distance, min_prominence)` finds local
maxima in a finite `Float64` sequence. The API intentionally supports exactly
these three criteria; threshold, plateau size, prominence window, width, and
other SciPy options are outside Nami's curated interface.

## Local maxima and plateaus

A sample is a local maximum when it is strictly greater than the nearest
unequal sample on each side. A flat run bounded on both sides by lower samples
is therefore one peak. Its reported index is the floor midpoint

```text
(left_edge + right_edge) // 2
```

matching `scipy.signal.find_peaks`. Endpoints are never peaks, including an
endpoint that belongs to a flat run, because a peak must have a bounding sample
on both sides. A monotone or constant signal has no peaks.

## Filters and ordering

Criteria are applied in this fixed order, matching SciPy's relevant ordering:

1. Height removes a peak when `signal[peak] < min_height`.
2. Distance selects peaks separated by at least `min_distance` samples.
3. Prominence removes a peak when its prominence is less than
   `min_prominence`.

Distance gives priority to higher peaks. Among peaks with equal heights, the
later index wins. Selection is equivalent to a stable ascending height sort
followed in reverse: an unremoved peak is kept, then every other not-yet-removed
peak at an index separation strictly less than `min_distance` is removed. A
peak already removed by a higher-priority peak cannot remove any other peak.

Prominence uses the full signal as `scipy.signal.peak_prominences` does without
`wlen`. From the peak, each side extends to the nearest sample that is strictly
higher than the peak or to the signal edge. The minimum sample in each of those
left and right intervals is the side's base. Prominence is

```text
signal[peak] - max(left_minimum, right_minimum)
```

Samples equal to the peak height do not stop the search. Prominences are always
computed for every peak that survives height and distance, even when
`min_prominence` is absent. When the prominence filter is present, each retained
prominence remains parallel to its retained index in the returned `Peaks`.

## Errors and invariants

`find_peaks` raises for:

- an empty signal, reporting its length (`0`);
- a non-finite signal sample, reporting its index and value;
- `min_distance < 1`, reporting the supplied distance;
- a non-finite `min_height` or `min_prominence`, reporting the supplied value.

`Peaks.indices()` and `Peaks.prominences()` return non-raising borrowed spans,
and `len(peaks)` returns the number of indices. The two owning lists must have
equal lengths. Construction validates this invariant; direct mutation of the
underscore-prefixed storage is out of contract, and `validate()` provides an
explicit checkpoint after unusual mutation.

## Allocation

The input span is borrowed and preserved. Peak discovery, stable distance
ordering, removal state, and filtering use temporary lists proportional to the
number of candidate peaks. The result owns one list of indices and one parallel
list of `Float64` prominences. No output sample buffer or copy of the input
signal is allocated.
