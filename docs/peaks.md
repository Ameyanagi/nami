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
left and right intervals is the side's base. Nami constructs nearest-greater
neighbors and a range-minimum index once per call, so it does not rescan the
whole signal for every peak. Prominence is

```text
signal[peak] - max(left_minimum, right_minimum)
```

Samples equal to the peak height do not stop the search. Prominences are always
computed for every peak that survives height and distance, even when
prominence bounds are absent. The base index changes only for a strictly lower
sample, so if an interval minimum occurs more than once, the occurrence closest
to the peak is retained.

Width follows `scipy.signal.peak_widths` at the requested `rel_height`, which
defaults to `0.5`. Its evaluation height is

```text
signal[peak] - prominence * rel_height
```

Starting at the peak, each side searches the range-minimum index toward the
base recorded by the prominence calculation until reaching the evaluation
height or that base. If the crossing falls between samples, its intersection
point is linearly interpolated. Width is the right intersection point minus the
left intersection point.

Widths and all related metadata are computed and stored for every returned
peak, even when no width filter is supplied. The borrowed parallel accessors
are:

- `indices()` and `heights()`;
- `prominences()`, `left_bases()`, and `right_bases()`;
- `widths()`, `width_heights()`, `left_ips()`, and `right_ips()`.

This makes one peak pass sufficient for filtering, annotation, and plotting.

## Errors and invariants

`find_peaks` raises for:

- an empty signal, reporting its length (`0`);
- a non-finite signal sample, reporting its index and value;
- `min_distance < 1`, reporting the supplied distance;
- a non-finite optional height, prominence, or width bound, reporting its name
  and supplied value;
- a non-finite or negative `rel_height`, reporting the supplied value.

Every `Peaks` accessor returns a non-raising borrowed span and `len(peaks)`
returns the shared parallel length. Construction validates that all metadata
lists match. Direct mutation of underscore-prefixed storage is out of contract,
and `validate()` provides an explicit checkpoint after unusual mutation.

## Reusable batch API

`find_peaks` is the simple owning convenience API. Repeated analysis can retain
both output and scratch storage:

```mojo
from nami import PeakWorkspace, Peaks, find_peaks_into

var output = Peaks()
var workspace = PeakWorkspace()
find_peaks_into(samples, output, workspace, min_prominence=0.25)
```

`find_peaks_into` validates before clearing output, borrows and preserves the
input, and reuses capacities retained by both values. A workspace is mutable,
not thread-safe, and must not be shared by concurrent calls. Use one workspace
per concurrent worker.

Distance priority is heap-ordered in `O(P log P)` for `P` candidate peaks.
Prominence and width indexes take `O(N)` construction storage and each selected
peak uses logarithmic range queries. The previous pairwise distance pass was
quadratic in `P`; the previous prominence calculation could rescan `N` samples
for every peak.
