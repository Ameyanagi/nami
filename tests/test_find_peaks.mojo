from nami import Peaks, find_peaks
from std.collections import List
from std.math import pi, sin
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def assert_near(actual: Float64, expected: Float64, tolerance: Float64 = 1e-12) raises:
    assert_true(
        abs(actual - expected) <= tolerance,
        msg="peak prominence differs from reference",
    )


def assert_peaks(
    actual: Peaks,
    expected_indices: List[Int],
    expected_prominences: List[Float64],
) raises:
    var indices = actual.indices()
    var prominences = actual.prominences()
    assert_equal(len(indices), len(expected_indices))
    assert_equal(len(prominences), len(expected_prominences))
    for index in range(len(indices)):
        assert_equal(indices[index], expected_indices[index])
        assert_near(prominences[index], expected_prominences[index])


def fixture_signal() -> List[Float64]:
    return [
        0.1,
        1.2,
        0.4,
        0.3,
        2.5,
        2.5,
        0.8,
        0.5,
        3.1,
        0.9,
        1.7,
        1.6,
        1.8,
        0.2,
        4.0,
        3.9,
        4.0,
        0.6,
        1.1,
        1.0,
        1.05,
        0.95,
        2.2,
        2.2,
        2.2,
        0.7,
        5.0,
        0.3,
        0.8,
        0.4,
    ]


def test_scipy_baseline_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(signal),
        [1, 4, 8, 10, 12, 14, 16, 18, 20, 23, 26, 28],
        [
            0.8999999999999999,
            2.0,
            2.9,
            0.09999999999999987,
            0.9,
            3.4,
            3.4,
            0.15000000000000013,
            0.050000000000000044,
            1.5000000000000002,
            4.7,
            0.4,
        ],
    )


def test_scipy_min_height_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(signal, min_height=1.5),
        [4, 8, 10, 12, 14, 16, 23, 26],
        [2.0, 2.9, 0.09999999999999987, 0.9, 3.4, 3.4, 1.5000000000000002, 4.7],
    )


def test_scipy_min_distance_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(signal, min_distance=3),
        [1, 4, 8, 12, 16, 20, 23, 26],
        [
            0.8999999999999999,
            2.0,
            2.9,
            0.9,
            3.4,
            0.050000000000000044,
            1.5000000000000002,
            4.7,
        ],
    )


def test_scipy_min_prominence_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(signal, min_prominence=1.0),
        [4, 8, 14, 16, 23, 26],
        [2.0, 2.9, 3.4, 3.4, 1.5000000000000002, 4.7],
    )


def test_scipy_combined_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(
            signal,
            min_height=1.0,
            min_distance=4,
            min_prominence=0.8,
        ),
        [4, 8, 12, 16, 26],
        [2.0, 2.9, 0.9, 3.4, 4.7],
    )


def test_scipy_min_width_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(signal, min_width=2.0),
        [4, 12, 14, 16, 23],
        [2.0, 0.9, 3.4, 3.4, 1.5000000000000002],
    )


def test_scipy_max_width_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(signal, max_width=2.5),
        [1, 4, 8, 10, 18, 20, 26, 28],
        [
            0.8999999999999999,
            2.0,
            2.9,
            0.09999999999999987,
            0.15000000000000013,
            0.050000000000000044,
            4.7,
            0.4,
        ],
    )


def test_scipy_width_range_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(signal, min_width=1.5, max_width=3.0),
        [4, 12, 14, 16],
        [2.0, 0.9, 3.4, 3.4],
    )


def test_scipy_max_height_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(signal, max_height=3.0),
        [1, 4, 10, 12, 18, 20, 23, 28],
        [
            0.8999999999999999,
            2.0,
            0.09999999999999987,
            0.9,
            0.15000000000000013,
            0.050000000000000044,
            1.5000000000000002,
            0.4,
        ],
    )


def test_scipy_height_range_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(signal, min_height=1.0, max_height=3.0),
        [1, 4, 10, 12, 18, 20, 23],
        [
            0.8999999999999999,
            2.0,
            0.09999999999999987,
            0.9,
            0.15000000000000013,
            0.050000000000000044,
            1.5000000000000002,
        ],
    )


def test_scipy_max_prominence_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(signal, max_prominence=2.0),
        [1, 4, 10, 12, 18, 20, 23, 28],
        [
            0.8999999999999999,
            2.0,
            0.09999999999999987,
            0.9,
            0.15000000000000013,
            0.050000000000000044,
            1.5000000000000002,
            0.4,
        ],
    )


def test_scipy_combined_all_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(
            signal,
            min_height=1.0,
            min_distance=3,
            min_prominence=0.5,
            max_prominence=4.0,
            min_width=1.0,
            max_width=4.0,
        ),
        [4, 8, 12, 16, 23],
        [2.0, 2.9, 0.9, 3.4, 1.5000000000000002],
    )


def test_scipy_rel_height_one_fixture() raises:
    var signal = fixture_signal()
    assert_peaks(
        find_peaks(signal, min_width=2.0, rel_height=1.0),
        [1, 4, 8, 12, 14, 16, 18, 23, 26],
        [
            0.8999999999999999,
            2.0,
            2.9,
            0.9,
            3.4,
            3.4,
            0.15000000000000013,
            1.5000000000000002,
            4.7,
        ],
    )


def test_two_sinusoid_prominent_peaks_follow_five_cycle_crests() raises:
    var signal = List[Float64](capacity=200)
    for index in range(200):
        var phase = 2.0 * pi * Float64(index) / 200.0
        signal.append(sin(5.0 * phase) + 0.4 * sin(13.0 * phase))

    var result = find_peaks(signal, min_prominence=0.5)
    var indices = result.indices()
    assert_equal(len(result), 5)
    for position in range(1, len(indices)):
        var spacing = indices[position] - indices[position - 1]
        # The 13-cycle component shifts the composite maxima by up to four
        # samples from a 5-cycle crest, so adjacent shifts can differ by six.
        assert_true(spacing >= 34)
        assert_true(spacing <= 46)


def test_odd_and_even_plateaus_use_floor_midpoints() raises:
    var odd_plateau: List[Float64] = [0.0, 1.0, 1.0, 1.0, 0.0]
    assert_peaks(find_peaks(odd_plateau), [2], [1.0])

    var even_plateau: List[Float64] = [0.0, 2.0, 2.0, 0.0]
    assert_peaks(find_peaks(even_plateau), [1], [2.0])


def test_endpoints_are_never_peaks() raises:
    var signal: List[Float64] = [3.0, 1.0, 2.0]
    var result = find_peaks(signal)
    assert_equal(len(result), 0)


def test_monotone_signal_has_no_peaks() raises:
    var signal: List[Float64] = [0.0, 1.0, 2.0, 3.0, 4.0]
    var result = find_peaks(signal)
    assert_equal(len(result), 0)
    assert_equal(len(result.indices()), 0)
    assert_equal(len(result.prominences()), 0)


def test_span_accessors_are_parallel_and_iterable() raises:
    var signal = fixture_signal()
    var result = find_peaks(signal, min_distance=3)
    var indices = result.indices()
    var prominences = result.prominences()
    var index_count = 0
    for _ in indices:
        index_count += 1
    var prominence_count = 0
    for _ in prominences:
        prominence_count += 1
    assert_equal(index_count, len(indices))
    assert_equal(prominence_count, len(prominences))
    assert_equal(len(indices), len(prominences))


def test_result_equality_and_writing() raises:
    var signal = fixture_signal()
    var first = find_peaks(signal, min_height=1.5)
    var second = find_peaks(signal, min_height=1.5)
    assert_true(first == second)
    assert_equal(String(first), "Peaks(count=8)")


def test_invalid_inputs_include_values() raises:
    var empty = List[Float64]()
    with assert_raises(contains="got signal_length=0"):
        _ = find_peaks(empty)

    var nonfinite: List[Float64] = [1.0, Float64("nan"), 0.0]
    with assert_raises(contains="got signal[1]=nan"):
        _ = find_peaks(nonfinite)

    var signal: List[Float64] = [0.0, 1.0, 0.0]
    with assert_raises(contains="got min_distance=0"):
        _ = find_peaks(signal, min_distance=0)
    with assert_raises(contains="got min_height=nan"):
        _ = find_peaks(signal, min_height=Float64("nan"))
    with assert_raises(contains="got min_prominence=nan"):
        _ = find_peaks(signal, min_prominence=Float64("nan"))


def test_new_invalid_inputs_include_values() raises:
    var signal: List[Float64] = [0.0, 1.0, 0.0]
    with assert_raises(contains="got max_height=nan"):
        _ = find_peaks(signal, max_height=Float64("nan"))
    with assert_raises(contains="got max_prominence=nan"):
        _ = find_peaks(signal, max_prominence=Float64("nan"))
    with assert_raises(contains="got min_width=nan"):
        _ = find_peaks(signal, min_width=Float64("nan"))
    with assert_raises(contains="got max_width=nan"):
        _ = find_peaks(signal, max_width=Float64("nan"))
    with assert_raises(contains="got rel_height=-0.5"):
        _ = find_peaks(signal, rel_height=-0.5)
    with assert_raises(contains="got rel_height=nan"):
        _ = find_peaks(signal, rel_height=Float64("nan"))


def test_explicit_validation_rejects_corrupted_parallel_storage() raises:
    var signal: List[Float64] = [0.0, 1.0, 0.0]
    var result = find_peaks(signal)
    result._prominences.append(0.0)
    with assert_raises(contains="got indices=1, prominences=2"):
        result.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
