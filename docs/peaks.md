# Peak finding

`find_peaks` finds local maxima in a finite `Float64` sequence and selects them
with four criteria: height, distance, prominence, and width. Height,
prominence, and width each have independent inclusive `min_*` and `max_*`
bounds. The API deliberately excludes threshold, `plateau_size`, `wlen`, and
SciPy-style `(min, max)` tuple bounds.

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

1. Height keeps a peak when `min_height <= signal[peak] <= max_height` for the
   supplied bounds.
2. Distance selects peaks separated by at least `min_distance` samples.
3. Prominence keeps a peak when
   `min_prominence <= prominence <= max_prominence` for the supplied bounds.
4. Width keeps a peak when `min_width <= width <= max_width` for the supplied
   bounds.

Each boundary comparison is inclusive. A missing bound leaves that side open,
and `min_*` is not cross-validated against `max_*`; an impossible range simply
selects no peaks.

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
prominence bounds are absent. The base index changes only for a strictly lower
sample, so if an interval minimum occurs more than once, the occurrence closest
to the peak is retained. Each retained prominence remains parallel to its
retained index in the returned `Peaks`.

Width follows `scipy.signal.peak_widths` at the requested `rel_height`, which
defaults to `0.5`. Its evaluation height is

```text
signal[peak] - prominence * rel_height
```

Starting at the peak, each side walks toward the base recorded by the
prominence calculation until reaching the evaluation height or that base. If
the crossing falls between samples, its intersection point is linearly
interpolated. Width is the right intersection point minus the left intersection
point. Widths are computed only when `min_width` or `max_width` is supplied.
They are a selection criterion only and are not stored on `Peaks`.

## Errors and invariants

`find_peaks` raises for:

- an empty signal, reporting its length (`0`);
- a non-finite signal sample, reporting its index and value;
- `min_distance < 1`, reporting the supplied distance;
- a non-finite optional height, prominence, or width bound, reporting its name
  and supplied value;
- a non-finite or negative `rel_height`, reporting the supplied value.

`Peaks.indices()` and `Peaks.prominences()` return non-raising borrowed spans,
and `len(peaks)` returns the number of indices. The two owning lists must have
equal lengths. Construction validates this invariant; direct mutation of the
underscore-prefixed storage is out of contract, and `validate()` provides an
explicit checkpoint after unusual mutation.

## Allocation

The input span is borrowed and preserved. Peak discovery, stable distance
ordering, removal state, and filtering use temporary lists proportional to the
number of candidate peaks. The result owns one list of indices and one parallel
list of `Float64` prominences. Requested widths are calculated as scalars during
filtering and do not add result storage. No output sample buffer or copy of the
input signal is allocated.
