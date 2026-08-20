from nami import (
    WindowNormalization,
    WindowSampling,
    blackman,
    hamming,
    hann,
)
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def assert_near(actual: Float64, expected: Float64, tolerance: Float64 = 1e-12) raises:
    assert_true(
        abs(actual - expected) <= tolerance,
        msg="window value differs from reference",
    )


def assert_values_near(actual: List[Float64], expected: List[Float64]) raises:
    assert_equal(len(actual), len(expected))
    for index in range(len(actual)):
        assert_near(actual[index], expected[index])


def test_hann_symmetric_reference() raises:
    assert_values_near(hann(5), [0.0, 0.5, 1.0, 0.5, 0.0])


def test_hamming_symmetric_reference() raises:
    assert_values_near(hamming(5), [0.08, 0.54, 1.0, 0.54, 0.08])


def test_blackman_symmetric_reference() raises:
    assert_values_near(blackman(5), [0.0, 0.34, 1.0, 0.34, 0.0])


def test_periodic_reference() raises:
    assert_values_near(
        hann(4, WindowSampling.PERIODIC),
        [0.0, 0.5, 1.0, 0.5],
    )
    assert_values_near(
        hamming(4, WindowSampling.PERIODIC),
        [0.08, 0.54, 1.0, 0.54],
    )
    assert_values_near(
        blackman(4, WindowSampling.PERIODIC),
        [0.0, 0.34, 1.0, 0.34],
    )


def test_periodic_matches_symmetric_extension() raises:
    for length in range(2, 17):
        var periodic = hann(length, WindowSampling.PERIODIC)
        var symmetric = hann(length + 1)
        for index in range(length):
            assert_near(periodic[index], symmetric[index])


def test_symmetric_windows_are_mirror_symmetric() raises:
    for length in range(2, 18):
        var values = blackman(length)
        for index in range(length):
            assert_near(values[index], values[length - index - 1])


def test_peak_normalization_rescales_even_symmetric_window() raises:
    var formula = hann(4)
    assert_values_near(formula, [0.0, 0.75, 0.75, 0.0])
    var normalized = hann(4, normalization=WindowNormalization.PEAK)
    assert_values_near(normalized, [0.0, 1.0, 1.0, 0.0])


def test_length_two_hann_rejects_peak_normalization() raises:
    assert_values_near(hann(2), [0.0, 0.0])
    with assert_raises(contains="cannot peak-normalize a numerically zero window"):
        _ = hann(2, normalization=WindowNormalization.PEAK)


def test_length_two_blackman_rejects_roundoff_amplification() raises:
    assert_values_near(blackman(2), [0.0, 0.0])
    with assert_raises(contains="cannot peak-normalize a numerically zero window"):
        _ = blackman(2, normalization=WindowNormalization.PEAK)


def test_empty_and_singleton_contract() raises:
    assert_equal(len(hann(0)), 0)
    assert_values_near(hann(1), [1.0])
    assert_values_near(hamming(1, WindowSampling.PERIODIC), [1.0])
    assert_values_near(blackman(1, normalization=WindowNormalization.PEAK), [1.0])


def test_negative_length_rejected() raises:
    with assert_raises(contains="window length must be non-negative"):
        _ = hann(-1)


def test_semantic_values_are_valid_by_construction() raises:
    assert_true(WindowSampling(periodic=False) == WindowSampling.SYMMETRIC)
    assert_true(WindowSampling(periodic=True) == WindowSampling.PERIODIC)
    assert_true(WindowNormalization(peak=False) == WindowNormalization.FORMULA)
    assert_true(WindowNormalization(peak=True) == WindowNormalization.PEAK)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
