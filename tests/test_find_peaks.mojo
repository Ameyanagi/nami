from nami import PeakWorkspace, Peaks, find_peaks, find_peaks_into
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


def assert_width_metadata(
    actual: Peaks,
    expected_widths: List[Float64],
    expected_left_bases: List[Int],
    expected_right_bases: List[Int],
    expected_width_heights: List[Float64],
    expected_left_ips: List[Float64],
    expected_right_ips: List[Float64],
) raises:
    var widths = actual.widths()
    var left_bases = actual.left_bases()
    var right_bases = actual.right_bases()
    var width_heights = actual.width_heights()
    var left_ips = actual.left_ips()
    var right_ips = actual.right_ips()
    assert_equal(len(widths), len(actual))
    assert_equal(len(expected_widths), len(actual))
    for index in range(len(actual)):
        assert_near(widths[index], expected_widths[index])
        assert_equal(left_bases[index], expected_left_bases[index])
        assert_equal(right_bases[index], expected_right_bases[index])
        assert_near(width_heights[index], expected_width_heights[index])
        assert_near(left_ips[index], expected_left_ips[index])
        assert_near(right_ips[index], expected_right_ips[index])


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


def test_scipy_baseline_metadata_fixture() raises:
    var signal = fixture_signal()
    var result = find_peaks(signal)
    var expected_heights: List[Float64] = [
        1.2,
        2.5,
        3.1,
        1.7,
        1.8,
        4.0,
        4.0,
        1.1,
        1.05,
        2.2,
        5.0,
        0.8,
    ]
    var expected_left_bases: List[Int] = [0, 0, 0, 9, 9, 0, 0, 17, 19, 17, 0, 27]
    var expected_right_bases: List[Int] = [3, 7, 13, 11, 13, 17, 17, 21, 21, 25, 27, 29]
    var expected_widths: List[Float64] = [
        0.971590909090909,
        2.0427807486631013,
        1.2167832167832158,
        0.5625000000000018,
        2.71875,
        2.947368421052632,
        2.947368421052632,
        0.8999999999999986,
        0.7500000000000036,
        3.1000000000000014,
        1.0465116279069768,
        0.8999999999999986,
    ]
    var expected_width_heights: List[Float64] = [
        0.75,
        1.5,
        1.6500000000000001,
        1.65,
        1.35,
        2.3,
        2.3,
        1.025,
        1.025,
        1.4500000000000002,
        2.65,
        0.6000000000000001,
    ]
    var expected_left_ips: List[Float64] = [
        0.590909090909091,
        3.5454545454545454,
        7.4423076923076925,
        9.9375,
        9.5625,
        13.552631578947368,
        13.552631578947368,
        17.85,
        19.499999999999996,
        21.4,
        25.453488372093023,
        27.6,
    ]
    var expected_right_ips: List[Float64] = [
        1.5625,
        5.588235294117647,
        8.659090909090908,
        10.500000000000002,
        12.28125,
        16.5,
        16.5,
        18.75,
        20.25,
        24.5,
        26.5,
        28.5,
    ]
    var heights = result.heights()
    assert_equal(len(heights), len(result))
    for index in range(len(result)):
        assert_near(heights[index], expected_heights[index])
    assert_width_metadata(
        result,
        expected_widths,
        expected_left_bases,
        expected_right_bases,
        expected_width_heights,
        expected_left_ips,
        expected_right_ips,
    )


def test_find_peaks_into_reuses_caller_owned_output_and_workspace() raises:
    var signal = fixture_signal()
    var output = Peaks()
    var workspace = PeakWorkspace()
    find_peaks_into(
        signal,
        output,
        workspace,
        min_distance=3,
        min_prominence=0.5,
        min_width=1.0,
    )
    assert_true(
        output
        == find_peaks(
            signal,
            min_distance=3,
            min_prominence=0.5,
            min_width=1.0,
        )
    )

    var second: List[Float64] = [0.0, 2.0, 0.0, 1.0, 0.0]
    find_peaks_into(second, output, workspace)
    assert_equal(len(output), 2)
    assert_equal(output.indices()[0], 1)
    assert_equal(output.indices()[1], 3)
    assert_near(output.heights()[0], 2.0)
    assert_near(output.widths()[0], 1.0)


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
    var result = find_peaks(
        signal,
        min_height=1.0,
        min_distance=3,
        min_prominence=0.5,
        max_prominence=4.0,
        min_width=1.0,
        max_width=4.0,
    )
    assert_peaks(
        result,
        [4, 8, 12, 16, 23],
        [2.0, 2.9, 0.9, 3.4, 1.5000000000000002],
    )
    var expected_heights: List[Float64] = [2.5, 3.1, 1.8, 4.0, 2.2]
    for index in range(len(result)):
        assert_near(result.heights()[index], expected_heights[index])
    assert_width_metadata(
        result,
        [
            2.0427807486631013,
            1.2167832167832158,
            2.71875,
            2.947368421052632,
            3.1000000000000014,
        ],
        [0, 0, 9, 0, 17],
        [7, 13, 13, 17, 25],
        [1.5, 1.6500000000000001, 1.35, 2.3, 1.4500000000000002],
        [
            3.5454545454545454,
            7.4423076923076925,
            9.5625,
            13.552631578947368,
            21.4,
        ],
        [5.588235294117647, 8.659090909090908, 12.28125, 16.5, 24.5],
    )


def test_scipy_rel_height_one_fixture() raises:
    var signal = fixture_signal()
    var result = find_peaks(signal, min_width=2.0, rel_height=1.0)
    assert_peaks(
        result,
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
    assert_width_metadata(
        result,
        [
            2.8181818181818175,
            3.909090909090909,
            12.909090909090908,
            3.5625,
            3.8947368421052637,
            3.8947368421052637,
            3.3000000000000007,
            7.800000000000001,
            13.973684210526315,
        ],
        [0, 0, 0, 9, 0, 0, 17, 17, 0],
        [3, 7, 13, 13, 17, 17, 21, 25, 27],
        [
            0.30000000000000004,
            0.5,
            0.20000000000000018,
            0.9,
            0.6000000000000001,
            0.6000000000000001,
            0.95,
            0.7,
            0.2999999999999998,
        ],
        [
            0.18181818181818188,
            3.090909090909091,
            0.09090909090909108,
            9.0,
            13.105263157894736,
            13.105263157894736,
            17.7,
            17.2,
            13.026315789473685,
        ],
        [2.9999999999999996, 7.0, 13.0, 12.5625, 17.0, 17.0, 21.0, 25.0, 27.0],
    )


def test_scipy_rel_height_zero_reports_zero_width_at_peak_positions() raises:
    var signal = fixture_signal()
    var result = find_peaks(signal, rel_height=0.0)
    assert_peaks(
        result,
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
    assert_width_metadata(
        result,
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        [0, 0, 0, 9, 9, 0, 0, 17, 19, 17, 0, 27],
        [3, 7, 13, 11, 13, 17, 17, 21, 21, 25, 27, 29],
        [1.2, 2.5, 3.1, 1.7, 1.8, 4.0, 4.0, 1.1, 1.05, 2.2, 5.0, 0.8],
        [1.0, 4.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 23.0, 26.0, 28.0],
        [1.0, 4.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 23.0, 26.0, 28.0],
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
