"""Dependency-free local peak finding for finite `Float64` sequences."""

from std.collections import List, Optional
from std.io import Writable, Writer
from std.math import isfinite


struct Peaks(Copyable, Equatable, Movable, Sized, Writable):
    """Own peak indices and their parallel, always-computed prominences.

    Direct mutation of `_indices` or `_prominences` is out of contract; use
    `validate()` for an explicit checkpoint after unusual mutation.
    """

    var _indices: List[Int]
    var _prominences: List[Float64]

    def __init__(
        out self,
        *,
        var _indices: List[Int],
        var _prominences: List[Float64],
    ) raises:
        self._indices = _indices^
        self._prominences = _prominences^
        self.validate()

    def indices(self) -> Span[Int, origin_of(self._indices)]:
        """Return a non-owning view of the peak indices."""
        return Span(self._indices)

    def prominences(self) -> Span[Float64, origin_of(self._prominences)]:
        """Return a non-owning view of the parallel peak prominences."""
        return Span(self._prominences)

    def __len__(self) -> Int:
        return len(self._indices)

    def validate(self) raises:
        """Raise if unusual direct field mutation broke parallel storage."""
        if len(self._indices) != len(self._prominences):
            raise Error(
                String(
                    "Peaks parallel lengths must match; got indices=",
                    len(self._indices),
                    ", prominences=",
                    len(self._prominences),
                )
            )

    def __eq__(self, other: Self) -> Bool:
        if len(self) != len(other):
            return False
        for index in range(len(self)):
            if self._indices[index] != other._indices[index]:
                return False
            if self._prominences[index] != other._prominences[index]:
                return False
        return True

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Peaks(count=", len(self), ")")


def _validate_find_peaks_inputs(
    signal: Span[Float64, _],
    min_height: Optional[Float64],
    min_distance: Int,
    min_prominence: Optional[Float64],
) raises:
    if len(signal) == 0:
        raise Error(
            String(
                "find_peaks signal must be non-empty; got signal_length=",
                len(signal),
            )
        )
    for index in range(len(signal)):
        if not isfinite(signal[index]):
            raise Error(
                String(
                    "find_peaks signal must contain only finite values; got signal[",
                    index,
                    "]=",
                    signal[index],
                )
            )
    if min_distance < 1:
        raise Error(
            String(
                "find_peaks min_distance must be >= 1; got min_distance=",
                min_distance,
            )
        )
    if min_height and not isfinite(min_height.value()):
        raise Error(
            String(
                "find_peaks min_height must be finite; got min_height=",
                min_height.value(),
            )
        )
    if min_prominence and not isfinite(min_prominence.value()):
        raise Error(
            String(
                "find_peaks min_prominence must be finite; got min_prominence=",
                min_prominence.value(),
            )
        )


def _local_maxima(signal: Span[Float64, _]) -> List[Int]:
    """Return local maxima in index order, folding plateaus to floor midpoints."""
    var peaks = List[Int]()
    var index = 1
    while index < len(signal) - 1:
        if signal[index] <= signal[index - 1]:
            index += 1
            continue

        var left_edge = index
        var right_edge = index
        while (
            right_edge + 1 < len(signal) and signal[right_edge + 1] == signal[left_edge]
        ):
            right_edge += 1

        if right_edge < len(signal) - 1:
            if signal[right_edge] > signal[right_edge + 1]:
                peaks.append(left_edge + (right_edge - left_edge) // 2)
        index = right_edge + 1
    return peaks^


def _stable_height_priority(signal: Span[Float64, _], peaks: Span[Int, _]) -> List[Int]:
    """Return candidate positions stably sorted by ascending peak height."""
    var order = List[Int](capacity=len(peaks))
    for peak_position in range(len(peaks)):
        order.append(peak_position)
        var position = len(order) - 1
        while position > 0:
            var previous_height = signal[peaks[order[position - 1]]]
            var current_height = signal[peaks[order[position]]]
            if previous_height <= current_height:
                break
            var previous = order[position - 1]
            order[position - 1] = order[position]
            order[position] = previous
            position -= 1
    return order^


def _select_by_distance(
    signal: Span[Float64, _],
    candidates: Span[Int, _],
    min_distance: Int,
) -> List[Int]:
    """Select candidates by descending height and later-index tie priority."""
    var removed = List[Bool](length=len(candidates), fill=False)
    if min_distance > 1:
        var priority = _stable_height_priority(signal, candidates)
        for reverse_position in range(len(priority)):
            var candidate_position = priority[len(priority) - reverse_position - 1]
            if removed[candidate_position]:
                continue

            var candidate_index = candidates[candidate_position]
            for other_position in range(len(candidates)):
                if other_position == candidate_position or removed[other_position]:
                    continue
                var other_index = candidates[other_position]
                var separation = (
                    candidate_index - other_index if candidate_index
                    >= other_index else other_index - candidate_index
                )
                if separation < min_distance:
                    removed[other_position] = True

    var selected = List[Int](capacity=len(candidates))
    for position in range(len(candidates)):
        if not removed[position]:
            selected.append(candidates[position])
    return selected^


def _peak_prominence(signal: Span[Float64, _], peak: Int) -> Float64:
    """Return full-window SciPy-style prominence for a trusted local peak."""
    var peak_height = signal[peak]
    var left_minimum = peak_height
    var left_index = peak
    while left_index > 0:
        left_index -= 1
        if signal[left_index] > peak_height:
            break
        if signal[left_index] < left_minimum:
            left_minimum = signal[left_index]

    var right_minimum = peak_height
    var right_index = peak
    while right_index < len(signal) - 1:
        right_index += 1
        if signal[right_index] > peak_height:
            break
        if signal[right_index] < right_minimum:
            right_minimum = signal[right_index]

    var contour_height = (
        left_minimum if left_minimum >= right_minimum else right_minimum
    )
    return peak_height - contour_height


def find_peaks(
    signal: Span[Float64, _],
    *,
    min_height: Optional[Float64] = None,
    min_distance: Int = 1,
    min_prominence: Optional[Float64] = None,
) raises -> Peaks:
    """Find local maxima and return their always-computed prominences.

    Flat maxima are reported once at their floor midpoint and endpoints are
    excluded. Filters run in height, distance, then prominence order. Distance
    gives higher peaks priority and gives the later index priority among equal
    heights. The input is preserved and must be non-empty and finite; distances
    must be positive and optional bounds must be finite.
    """
    _validate_find_peaks_inputs(
        signal,
        min_height,
        min_distance,
        min_prominence,
    )

    var local_maxima = _local_maxima(signal)
    var height_filtered = List[Int](capacity=len(local_maxima))
    for position in range(len(local_maxima)):
        var peak = local_maxima[position]
        if min_height and signal[peak] < min_height.value():
            continue
        height_filtered.append(peak)

    var distance_filtered = _select_by_distance(
        signal,
        height_filtered,
        min_distance,
    )
    var indices = List[Int](capacity=len(distance_filtered))
    var prominences = List[Float64](capacity=len(distance_filtered))
    for position in range(len(distance_filtered)):
        var peak = distance_filtered[position]
        var prominence = _peak_prominence(signal, peak)
        if min_prominence and prominence < min_prominence.value():
            continue
        indices.append(peak)
        prominences.append(prominence)

    return Peaks(_indices=indices^, _prominences=prominences^)
