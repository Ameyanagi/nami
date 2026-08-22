"""Dependency-free local peak finding for finite `Float64` sequences."""

from std.collections import List, Optional
from std.io import Writable, Writer
from std.math import isfinite


struct Peaks(Copyable, Equatable, Movable, Sized, Writable):
    """Own peak indices and parallel SciPy-compatible peak metadata.

    Heights, prominences, bases, interpolated widths, width heights, and
    intersection positions are computed for every selected peak. Direct
    mutation of underscore-prefixed storage is out of contract; use
    `validate()` for an explicit checkpoint after unusual mutation.
    """

    var _indices: List[Int]
    var _heights: List[Float64]
    var _prominences: List[Float64]
    var _left_bases: List[Int]
    var _right_bases: List[Int]
    var _widths: List[Float64]
    var _width_heights: List[Float64]
    var _left_ips: List[Float64]
    var _right_ips: List[Float64]

    def __init__(out self):
        """Construct empty caller-owned peak output for `find_peaks_into`."""
        self._indices = List[Int]()
        self._heights = List[Float64]()
        self._prominences = List[Float64]()
        self._left_bases = List[Int]()
        self._right_bases = List[Int]()
        self._widths = List[Float64]()
        self._width_heights = List[Float64]()
        self._left_ips = List[Float64]()
        self._right_ips = List[Float64]()

    def __init__(
        out self,
        *,
        var _indices: List[Int],
        var _heights: List[Float64],
        var _prominences: List[Float64],
        var _left_bases: List[Int],
        var _right_bases: List[Int],
        var _widths: List[Float64],
        var _width_heights: List[Float64],
        var _left_ips: List[Float64],
        var _right_ips: List[Float64],
    ) raises:
        self._indices = _indices^
        self._heights = _heights^
        self._prominences = _prominences^
        self._left_bases = _left_bases^
        self._right_bases = _right_bases^
        self._widths = _widths^
        self._width_heights = _width_heights^
        self._left_ips = _left_ips^
        self._right_ips = _right_ips^
        self.validate()

    def indices(self) -> Span[Int, origin_of(self._indices)]:
        """Return a non-owning view of the peak indices."""
        return Span(self._indices)

    def prominences(self) -> Span[Float64, origin_of(self._prominences)]:
        """Return a non-owning view of the parallel peak prominences."""
        return Span(self._prominences)

    def heights(self) -> Span[Float64, origin_of(self._heights)]:
        """Return a non-owning view of the parallel peak heights."""
        return Span(self._heights)

    def left_bases(self) -> Span[Int, origin_of(self._left_bases)]:
        """Return the closest left base among equal strict minima."""
        return Span(self._left_bases)

    def right_bases(self) -> Span[Int, origin_of(self._right_bases)]:
        """Return the closest right base among equal strict minima."""
        return Span(self._right_bases)

    def widths(self) -> Span[Float64, origin_of(self._widths)]:
        """Return interpolated widths at the configured relative height."""
        return Span(self._widths)

    def width_heights(self) -> Span[Float64, origin_of(self._width_heights)]:
        """Return the evaluation height used for each width."""
        return Span(self._width_heights)

    def left_ips(self) -> Span[Float64, origin_of(self._left_ips)]:
        """Return interpolated left width intersections."""
        return Span(self._left_ips)

    def right_ips(self) -> Span[Float64, origin_of(self._right_ips)]:
        """Return interpolated right width intersections."""
        return Span(self._right_ips)

    def __len__(self) -> Int:
        return len(self._indices)

    def validate(self) raises:
        """Raise if unusual direct field mutation broke parallel storage."""
        var count = len(self._indices)
        if len(self._prominences) != count:
            raise Error(
                String(
                    "Peaks parallel lengths must match; got indices=",
                    count,
                    ", prominences=",
                    len(self._prominences),
                )
            )
        if (
            len(self._heights) != count
            or len(self._left_bases) != count
            or len(self._right_bases) != count
            or len(self._widths) != count
            or len(self._width_heights) != count
            or len(self._left_ips) != count
            or len(self._right_ips) != count
        ):
            raise Error("Peaks metadata lengths must all match indices")

    def __eq__(self, other: Self) -> Bool:
        if len(self) != len(other):
            return False
        for index in range(len(self)):
            if self._indices[index] != other._indices[index]:
                return False
            if self._heights[index] != other._heights[index]:
                return False
            if self._prominences[index] != other._prominences[index]:
                return False
            if self._left_bases[index] != other._left_bases[index]:
                return False
            if self._right_bases[index] != other._right_bases[index]:
                return False
            if self._widths[index] != other._widths[index]:
                return False
            if self._width_heights[index] != other._width_heights[index]:
                return False
            if self._left_ips[index] != other._left_ips[index]:
                return False
            if self._right_ips[index] != other._right_ips[index]:
                return False
        return True

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Peaks(count=", len(self), ")")

    def _clear(mut self):
        self._indices.clear()
        self._heights.clear()
        self._prominences.clear()
        self._left_bases.clear()
        self._right_bases.clear()
        self._widths.clear()
        self._width_heights.clear()
        self._left_ips.clear()
        self._right_ips.clear()


struct PeakWorkspace:
    """Reusable scratch storage for allocation-stable peak analysis.

    One workspace may serve repeated sequential calls and retains capacity for
    the largest signal seen. It is mutable and not thread-safe.
    """

    var _candidates: List[Int]
    var _priority: List[Int]
    var _removed: List[Bool]
    var _stack: List[Int]
    var _left_greater: List[Int]
    var _right_greater: List[Int]
    var _min_values: List[Float64]
    var _min_left_indices: List[Int]
    var _min_right_indices: List[Int]
    var _tree_base: Int

    def __init__(out self):
        self._candidates = List[Int]()
        self._priority = List[Int]()
        self._removed = List[Bool]()
        self._stack = List[Int]()
        self._left_greater = List[Int]()
        self._right_greater = List[Int]()
        self._min_values = List[Float64]()
        self._min_left_indices = List[Int]()
        self._min_right_indices = List[Int]()
        self._tree_base = 0


struct _PeakProminence(Copyable, Movable):
    """Store a peak's prominence and closest strict-minimum bases."""

    var prominence: Float64
    var left_base: Int
    var right_base: Int

    def __init__(
        out self,
        prominence: Float64,
        left_base: Int,
        right_base: Int,
    ):
        self.prominence = prominence
        self.left_base = left_base
        self.right_base = right_base


def _validate_find_peaks_inputs(
    signal: Span[Float64, _],
    min_height: Optional[Float64],
    max_height: Optional[Float64],
    min_distance: Int,
    min_prominence: Optional[Float64],
    max_prominence: Optional[Float64],
    min_width: Optional[Float64],
    max_width: Optional[Float64],
    rel_height: Float64,
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
    if max_height and not isfinite(max_height.value()):
        raise Error(
            String(
                "find_peaks max_height must be finite; got max_height=",
                max_height.value(),
            )
        )
    if min_prominence and not isfinite(min_prominence.value()):
        raise Error(
            String(
                "find_peaks min_prominence must be finite; got min_prominence=",
                min_prominence.value(),
            )
        )
    if max_prominence and not isfinite(max_prominence.value()):
        raise Error(
            String(
                "find_peaks max_prominence must be finite; got max_prominence=",
                max_prominence.value(),
            )
        )
    if min_width and not isfinite(min_width.value()):
        raise Error(
            String(
                "find_peaks min_width must be finite; got min_width=",
                min_width.value(),
            )
        )
    if max_width and not isfinite(max_width.value()):
        raise Error(
            String(
                "find_peaks max_width must be finite; got max_width=",
                max_width.value(),
            )
        )
    if not isfinite(rel_height) or rel_height < 0.0:
        raise Error(
            String(
                "find_peaks rel_height must be finite and >= 0; got rel_height=",
                rel_height,
            )
        )


def _local_maxima_into(
    signal: Span[Float64, _],
    min_height: Optional[Float64],
    max_height: Optional[Float64],
    mut peaks: List[Int],
):
    """Write height-filtered maxima, folding plateaus to floor midpoints."""
    peaks.clear()
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
                var peak = left_edge + (right_edge - left_edge) // 2
                if min_height and signal[peak] < min_height.value():
                    index = right_edge + 1
                    continue
                if max_height and signal[peak] > max_height.value():
                    index = right_edge + 1
                    continue
                peaks.append(peak)
        index = right_edge + 1


def _lower_priority(
    signal: Span[Float64, _],
    candidates: Span[Int, _],
    left_position: Int,
    right_position: Int,
) -> Bool:
    var left_index = candidates[left_position]
    var right_index = candidates[right_position]
    if signal[left_index] != signal[right_index]:
        return signal[left_index] < signal[right_index]
    return left_index < right_index


def _sift_priority_heap(
    signal: Span[Float64, _],
    candidates: Span[Int, _],
    mut order: List[Int],
    root: Int,
    count: Int,
):
    var current = root
    while True:
        var child = 2 * current + 1
        if child >= count:
            return
        if child + 1 < count and _lower_priority(
            signal, candidates, order[child], order[child + 1]
        ):
            child += 1
        if not _lower_priority(signal, candidates, order[current], order[child]):
            return
        var temporary = order[current]
        order[current] = order[child]
        order[child] = temporary
        current = child


def _height_priority_into(
    signal: Span[Float64, _],
    candidates: Span[Int, _],
    mut order: List[Int],
):
    """Write ascending `(height, index)` priority in O(P log P)."""
    order.clear()
    order.resize(len(candidates), 0)
    for position in range(len(candidates)):
        order[position] = position

    var root = len(order) // 2
    while root > 0:
        root -= 1
        _sift_priority_heap(signal, candidates, order, root, len(order))
    var end = len(order)
    while end > 1:
        end -= 1
        var temporary = order[0]
        order[0] = order[end]
        order[end] = temporary
        _sift_priority_heap(signal, candidates, order, 0, end)


def _select_by_distance(
    signal: Span[Float64, _],
    candidates: Span[Int, _],
    min_distance: Int,
    mut order: List[Int],
    mut removed: List[Bool],
):
    """Mark distance exclusions in O(P log P) time and O(P) scratch."""
    removed.clear()
    removed.resize(len(candidates), False)
    if min_distance == 1 or len(candidates) < 2:
        return

    _height_priority_into(signal, candidates, order)
    for reverse_position in range(len(order)):
        var candidate_position = order[len(order) - reverse_position - 1]
        if removed[candidate_position]:
            continue
        var candidate_index = candidates[candidate_position]

        var left_position = candidate_position
        while left_position > 0:
            left_position -= 1
            if candidate_index - candidates[left_position] >= min_distance:
                break
            removed[left_position] = True

        var right_position = candidate_position + 1
        while right_position < len(candidates):
            if candidates[right_position] - candidate_index >= min_distance:
                break
            removed[right_position] = True
            right_position += 1


def _prepare_greater_neighbors(signal: Span[Float64, _], mut workspace: PeakWorkspace):
    workspace._left_greater.clear()
    workspace._left_greater.resize(len(signal), -1)
    workspace._right_greater.clear()
    workspace._right_greater.resize(len(signal), -1)
    workspace._stack.clear()
    for index in range(len(signal)):
        while (
            len(workspace._stack) > 0
            and signal[workspace._stack[len(workspace._stack) - 1]] <= signal[index]
        ):
            _ = workspace._stack.pop()
        if len(workspace._stack) > 0:
            workspace._left_greater[index] = workspace._stack[len(workspace._stack) - 1]
        workspace._stack.append(index)

    workspace._stack.clear()
    for reverse_index in range(len(signal)):
        var index = len(signal) - reverse_index - 1
        while (
            len(workspace._stack) > 0
            and signal[workspace._stack[len(workspace._stack) - 1]] <= signal[index]
        ):
            _ = workspace._stack.pop()
        if len(workspace._stack) > 0:
            workspace._right_greater[index] = workspace._stack[
                len(workspace._stack) - 1
            ]
        workspace._stack.append(index)


def _prepare_minimum_tree(signal: Span[Float64, _], mut workspace: PeakWorkspace):
    var base = 1
    while base < len(signal):
        base *= 2
    workspace._tree_base = base
    var tree_size = 2 * base
    workspace._min_values.clear()
    workspace._min_values.resize(tree_size, Float64.MAX)
    workspace._min_left_indices.clear()
    workspace._min_left_indices.resize(tree_size, -1)
    workspace._min_right_indices.clear()
    workspace._min_right_indices.resize(tree_size, -1)
    for index in range(len(signal)):
        var node = base + index
        workspace._min_values[node] = signal[index]
        workspace._min_left_indices[node] = index
        workspace._min_right_indices[node] = index

    var node = base
    while node > 1:
        node -= 1
        var left = 2 * node
        var right = left + 1
        var left_value = workspace._min_values[left]
        var right_value = workspace._min_values[right]
        if left_value < right_value:
            workspace._min_values[node] = left_value
            workspace._min_left_indices[node] = workspace._min_left_indices[left]
            workspace._min_right_indices[node] = workspace._min_right_indices[left]
        elif right_value < left_value:
            workspace._min_values[node] = right_value
            workspace._min_left_indices[node] = workspace._min_left_indices[right]
            workspace._min_right_indices[node] = workspace._min_right_indices[right]
        else:
            workspace._min_values[node] = left_value
            workspace._min_left_indices[node] = (
                workspace._min_left_indices[left] if workspace._min_left_indices[left]
                >= 0 else workspace._min_left_indices[right]
            )
            workspace._min_right_indices[node] = (
                workspace._min_right_indices[right] if workspace._min_right_indices[
                    right
                ]
                >= 0 else workspace._min_right_indices[left]
            )


def _minimum_base(
    workspace: PeakWorkspace,
    left: Int,
    right: Int,
    *,
    prefer_right: Bool,
) -> Int:
    var query_left = left + workspace._tree_base
    var query_right = right + workspace._tree_base
    var best_value = Float64.MAX
    var best_index = -1
    while query_left <= query_right:
        if query_left % 2 == 1:
            var index = workspace._min_right_indices[
                query_left
            ] if prefer_right else workspace._min_left_indices[query_left]
            var value = workspace._min_values[query_left]
            if value < best_value or (
                value == best_value
                and (
                    best_index < 0
                    or (prefer_right and index > best_index)
                    or (not prefer_right and index < best_index)
                )
            ):
                best_value = value
                best_index = index
            query_left += 1
        if query_right % 2 == 0:
            var index = workspace._min_right_indices[
                query_right
            ] if prefer_right else workspace._min_left_indices[query_right]
            var value = workspace._min_values[query_right]
            if value < best_value or (
                value == best_value
                and (
                    best_index < 0
                    or (prefer_right and index > best_index)
                    or (not prefer_right and index < best_index)
                )
            ):
                best_value = value
                best_index = index
            query_right -= 1
        query_left //= 2
        query_right //= 2
    return best_index


def _peak_prominence(
    signal: Span[Float64, _], peak: Int, workspace: PeakWorkspace
) -> _PeakProminence:
    """Return full-window prominence via greater-neighbor and RMQ indexes."""
    var left_boundary = workspace._left_greater[peak] + 1
    var right_greater = workspace._right_greater[peak]
    var right_boundary = right_greater - 1 if right_greater >= 0 else len(signal) - 1
    var left_base = _minimum_base(workspace, left_boundary, peak, prefer_right=True)
    var right_base = _minimum_base(workspace, peak, right_boundary, prefer_right=False)
    var contour_height = (
        signal[left_base] if signal[left_base]
        >= signal[right_base] else signal[right_base]
    )
    return _PeakProminence(signal[peak] - contour_height, left_base, right_base)


def _find_leftmost_at_most(
    tree: Span[Float64, _],
    base: Int,
    node: Int,
    node_left: Int,
    node_right: Int,
    query_left: Int,
    query_right: Int,
    threshold: Float64,
) -> Int:
    if node_right < query_left or node_left > query_right or tree[node] > threshold:
        return -1
    if node_left == node_right:
        return node_left
    var midpoint = node_left + (node_right - node_left) // 2
    var found = _find_leftmost_at_most(
        tree,
        base,
        2 * node,
        node_left,
        midpoint,
        query_left,
        query_right,
        threshold,
    )
    if found >= 0:
        return found
    return _find_leftmost_at_most(
        tree,
        base,
        2 * node + 1,
        midpoint + 1,
        node_right,
        query_left,
        query_right,
        threshold,
    )


def _find_rightmost_at_most(
    tree: Span[Float64, _],
    base: Int,
    node: Int,
    node_left: Int,
    node_right: Int,
    query_left: Int,
    query_right: Int,
    threshold: Float64,
) -> Int:
    if node_right < query_left or node_left > query_right or tree[node] > threshold:
        return -1
    if node_left == node_right:
        return node_left
    var midpoint = node_left + (node_right - node_left) // 2
    var found = _find_rightmost_at_most(
        tree,
        base,
        2 * node + 1,
        midpoint + 1,
        node_right,
        query_left,
        query_right,
        threshold,
    )
    if found >= 0:
        return found
    return _find_rightmost_at_most(
        tree,
        base,
        2 * node,
        node_left,
        midpoint,
        query_left,
        query_right,
        threshold,
    )


def _peak_width(
    signal: Span[Float64, _],
    peak: Int,
    properties: _PeakProminence,
    rel_height: Float64,
    workspace: PeakWorkspace,
) -> Tuple[Float64, Float64, Float64, Float64]:
    """Return width, height, and intersections using indexed threshold search."""
    var height = signal[peak] - properties.prominence * rel_height
    var left_index = _find_rightmost_at_most(
        workspace._min_values,
        workspace._tree_base,
        1,
        0,
        workspace._tree_base - 1,
        properties.left_base,
        peak,
        height,
    )
    if left_index < 0:
        left_index = properties.left_base
    var left_ip = Float64(left_index)
    if signal[left_index] < height:
        left_ip += (height - signal[left_index]) / (
            signal[left_index + 1] - signal[left_index]
        )
    var right_index = _find_leftmost_at_most(
        workspace._min_values,
        workspace._tree_base,
        1,
        0,
        workspace._tree_base - 1,
        peak,
        properties.right_base,
        height,
    )
    if right_index < 0:
        right_index = properties.right_base
    var right_ip = Float64(right_index)
    if signal[right_index] < height:
        right_ip -= (height - signal[right_index]) / (
            signal[right_index - 1] - signal[right_index]
        )
    return (right_ip - left_ip, height, left_ip, right_ip)


def find_peaks_into(
    signal: Span[Float64, _],
    mut output: Peaks,
    mut workspace: PeakWorkspace,
    *,
    min_height: Optional[Float64] = None,
    max_height: Optional[Float64] = None,
    min_distance: Int = 1,
    min_prominence: Optional[Float64] = None,
    max_prominence: Optional[Float64] = None,
    min_width: Optional[Float64] = None,
    max_width: Optional[Float64] = None,
    rel_height: Float64 = 0.5,
) raises:
    """Write local maxima and complete metadata into caller-owned storage.

    Flat maxima are reported once at their floor midpoint and endpoints are
    excluded. Filters run in height, distance, prominence, then width order.
    Distance gives higher peaks priority and gives the later index priority
    among equal heights. Prominences, bases, and widths are found from reusable
    nearest-greater and range-minimum indexes instead of rescanning the signal
    for each peak. `output` and `workspace` retain their allocations across
    calls; do not alias them across concurrent calls.
    """
    _validate_find_peaks_inputs(
        signal,
        min_height,
        max_height,
        min_distance,
        min_prominence,
        max_prominence,
        min_width,
        max_width,
        rel_height,
    )

    _local_maxima_into(
        signal,
        min_height,
        max_height,
        workspace._candidates,
    )
    _select_by_distance(
        signal,
        workspace._candidates,
        min_distance,
        workspace._priority,
        workspace._removed,
    )
    output._clear()
    if len(workspace._candidates) == 0:
        return

    _prepare_greater_neighbors(signal, workspace)
    _prepare_minimum_tree(signal, workspace)
    var required_capacity = len(workspace._candidates)
    output._indices.reserve(required_capacity)
    output._heights.reserve(required_capacity)
    output._prominences.reserve(required_capacity)
    output._left_bases.reserve(required_capacity)
    output._right_bases.reserve(required_capacity)
    output._widths.reserve(required_capacity)
    output._width_heights.reserve(required_capacity)
    output._left_ips.reserve(required_capacity)
    output._right_ips.reserve(required_capacity)

    for position in range(len(workspace._candidates)):
        if workspace._removed[position]:
            continue
        var peak = workspace._candidates[position]
        var properties = _peak_prominence(signal, peak, workspace)
        if min_prominence and properties.prominence < min_prominence.value():
            continue
        if max_prominence and properties.prominence > max_prominence.value():
            continue
        var width, width_height, left_ip, right_ip = _peak_width(
            signal, peak, properties, rel_height, workspace
        )
        if min_width and width < min_width.value():
            continue
        if max_width and width > max_width.value():
            continue
        output._indices.append(peak)
        output._heights.append(signal[peak])
        output._prominences.append(properties.prominence)
        output._left_bases.append(properties.left_base)
        output._right_bases.append(properties.right_base)
        output._widths.append(width)
        output._width_heights.append(width_height)
        output._left_ips.append(left_ip)
        output._right_ips.append(right_ip)


def find_peaks(
    signal: Span[Float64, _],
    *,
    min_height: Optional[Float64] = None,
    max_height: Optional[Float64] = None,
    min_distance: Int = 1,
    min_prominence: Optional[Float64] = None,
    max_prominence: Optional[Float64] = None,
    min_width: Optional[Float64] = None,
    max_width: Optional[Float64] = None,
    rel_height: Float64 = 0.5,
) raises -> Peaks:
    """Find local maxima and return complete SciPy-compatible metadata.

    This convenient owning API delegates to `find_peaks_into`. Repeated or
    latency-sensitive analysis should retain a `Peaks` and `PeakWorkspace` and
    call `find_peaks_into` to reuse all output and scratch allocations.
    """
    var output = Peaks()
    var workspace = PeakWorkspace()
    find_peaks_into(
        signal,
        output,
        workspace,
        min_height=min_height,
        max_height=max_height,
        min_distance=min_distance,
        min_prominence=min_prominence,
        max_prominence=max_prominence,
        min_width=min_width,
        max_width=max_width,
        rel_height=rel_height,
    )
    return output^
